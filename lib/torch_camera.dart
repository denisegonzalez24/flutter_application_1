import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

// === Configuración de WebSocket ===
// - Emulador AVD: 'ws://10.0.2.2:13001/ws'
// - Dispositivo físico: 'ws://<IP_de_tu_PC>:13001/ws'
// - Server público (TLS):
const String kWsBase = 'wss://node2.liit.com.ar'; // sin /ws acá
const String kToken = '123456';

class TorchCameraPage extends StatefulWidget {
  const TorchCameraPage({super.key});

  @override
  State<TorchCameraPage> createState() => _TorchCameraPageState();
}

class _TorchCameraPageState extends State<TorchCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _torchOn = false;
  String? _error;

  // WebSocket
  WebSocket? _ws;
  StreamSubscription? _wsSub;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _manuallyClosed = false;

  // Ringtones (usa instancia en tu versión de la librería)
  late final FlutterRingtonePlayer _ringer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _ringer = FlutterRingtonePlayer(); // instancia ✅

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera().then((_) => _connectSocket());
    });
  }

  Uri get _socketUri => Uri.parse('$kWsBase/ws');

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      _camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final ctrl = CameraController(
        _camera!,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await ctrl.initialize();

      if (!mounted) return;
      setState(() {
        _controller = ctrl;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo inicializar la cámara: $e');
    }
  }

  Future<void> _setTorch(bool turnOn) async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;

    try {
      await ctrl.setFlashMode(turnOn ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() {
          _torchOn = turnOn;
          _error = null;
        });
      }
    } on CameraException catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Error torch: ${e.code} ${e.description ?? ""}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error torch: $e');
      }
    }
  }

  // ---- WebSocket helpers ----

  void _sendWs(Map<String, dynamic> payload) {
    final ws = _ws;
    if (ws == null) return; // evita "Cannot send Null"
    try {
      ws.add(json.encode(payload));
    } catch (e) {
      setState(() => _error = 'WS send error: $e');
    }
  }

  String _genAckId() => 't_${DateTime.now().millisecondsSinceEpoch}';

  void _sendTorchAck({
    required String? requestId,
    required bool ok,
    String? err,
  }) {
    final ack = <String, dynamic>{
      "id": requestId ?? _genAckId(),
      "op": "torch",
      "ok": ok ? "true" : "false",
      if (err != null) "err": err,
    };
    _sendWs(ack);
  }

  Future<void> _connectSocket() async {
    _manuallyClosed = false;
    _cancelReconnect();
    try {
      setState(() => _error = null);

      _ws = await WebSocket.connect(
        _socketUri.toString(),
        headers: {'Authorization': 'Bearer $kToken'},
      );
      _ws?.pingInterval = const Duration(seconds: 20);

      _wsSub = _ws!.listen(
        _onWsMessage,
        onDone: _onWsDone,
        onError: (e) {
          if (mounted) setState(() => _error = 'WS error: $e');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo conectar al WS: $e');
      _scheduleReconnect();
    }
  }

  void _onWsMessage(dynamic data) {
    try {
      if (data is List<int>) {
        data = utf8.decode(data, allowMalformed: true);
      }
      if (data is! String) return;

      final trimmed = data.trim();
      dynamic decoded;

      try {
        decoded = json.decode(trimmed);
      } catch (_) {
        decoded = null;
      }

      if (decoded is Map) {
        final op = decoded["op"];
        final cmd = decoded["cmd"];
        final reqId = decoded["id"] as String?;

        if (op == "ping") {
          final ts = decoded["ts"];
          _sendWs({
            "id": reqId ?? _genAckId(),
            "op": "ping",
            "ok": "true",
            if (ts != null) "ts": ts,
          });
          return;
        }

        if (op == "torch") {
          final val = decoded["on"];
          bool? desired;
          if (val is bool) desired = val;
          if (val is num) desired = val != 0;
          if (val is String) {
            final s = val.toLowerCase();
            if (s == "true" ||
                s == "on" ||
                s == "1" ||
                s == "encender" ||
                s == "prender") {
              desired = true;
            }
            if (s == "false" || s == "off" || s == "0" || s == "apagar") {
              desired = false;
            }
          }

          if (desired != null) {
            _setTorch(desired).whenComplete(() {
              final ok = _error == null;
              _sendTorchAck(requestId: reqId, ok: ok, err: ok ? null : _error);
            });
          } else {
            _sendTorchAck(
              requestId: reqId,
              ok: false,
              err: "payload invalido: on",
            );
          }
          return;
        }

        // === SONIDO NATIVO ===
        if (cmd == "sound") {
          final args = decoded["args"];
          final tipo = (args is Map) ? (args["tipo"] as String?) : null;
          _handleSound(tipo);
          _sendWs({
            "id": reqId ?? _genAckId(),
            "cmd": "sound",
            "ok": "true",
            if (tipo != null) "tipo": "muerte",
          });
          return;
        }

        _sendWs({
          "id": reqId ?? _genAckId(),
          "op": "$op",
          "cmd": "$cmd",
          "ok": "false",
          "err": "operacion/comando desconocido",
        });
        return;
      }

      final norm = trimmed.toLowerCase();
      final desired = _parseDesiredFromText(norm);

      if (desired != null) {
        _setTorch(desired).whenComplete(() {
          _sendTorchAck(requestId: null, ok: _error == null, err: _error);
        });
      } else {
        if (mounted) setState(() => _error = 'WS msg desconocido: "$data"');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error parseando WS: $e');
    }
  }

  bool _isOnWord(String s) =>
      s == 'on' ||
      s == 'encender' ||
      s == 'prender' ||
      s == 'true' ||
      s == '1' ||
      s == 'torch_on';

  bool _isOffWord(String s) =>
      s == 'off' ||
      s == 'apagar' ||
      s == 'false' ||
      s == '0' ||
      s == 'torch_off';

  bool? _parseDesiredFromText(String s) {
    final m = RegExp(r'on\s*[:=]\s*([A-Za-z0-9_]+)').firstMatch(s);
    if (m != null) {
      final v = m.group(1)!.toLowerCase();
      if (_isOnWord(v)) return true;
      if (_isOffWord(v)) return false;
    }
    if (_isOnWord(s)) return true;
    if (_isOffWord(s)) return false;
    return null;
  }

  void _onWsDone() {
    if (_manuallyClosed) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectAttempt++;
    final delay = Duration(
      seconds: _reconnectBackoffSeconds(_reconnectAttempt),
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _connectSocket);
    if (mounted) {
      setState(() {
        _error = 'Reconectando WS en ${delay.inSeconds}s...';
      });
    }
  }

  int _reconnectBackoffSeconds(int attempt) {
    final v = 1 << (attempt - 1);
    return v > 10 ? 10 : v;
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
  }

  Future<void> _closeSocket() async {
    _manuallyClosed = true;
    _cancelReconnect();
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
  }

  // === SONIDO NATIVO ===
  Future<void> _handleSound(String? tipoRaw) async {
    final tipo = (tipoRaw ?? '').toLowerCase().trim();

    try {
      switch (tipo) {
        case 'muerte':
          await _ringer.playAlarm(looping: false, volume: 1.0, asAlarm: true);
          break;

        case 'alerta':
          await _ringer.playNotification(looping: false, volume: 1.0);
          break;

        case 'pitido':
        default:
          await SystemSound.play(SystemSoundType.click);
          break;
      }

      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error sonido ($tipo): $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _closeSocket();
      if (ctrl != null && ctrl.value.isInitialized) {
        ctrl.dispose();
        _controller = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      _initCamera().then((_) => _connectSocket());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeSocket();
    _controller?.dispose();
    _ringer.stop(); // detener instancia
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;

    return Scaffold(
      appBar: AppBar(title: const Text('Torch con WebSocket')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusTile(
              label: 'Cámara',
              value: (ctrl?.value.isInitialized ?? false)
                  ? 'Inicializada'
                  : 'No lista',
            ),
            const SizedBox(height: 8),
            _StatusTile(
              label: 'Linterna',
              value: _torchOn ? 'Encendida' : 'Apagada',
            ),
            const SizedBox(height: 8),
            _StatusTile(
              label: 'WS URL',
              value: _socketUri.toString(),
              monospace: true,
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(255, 0, 0, 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color.fromRGBO(255, 0, 0, 0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                onPressed: (ctrl == null || !ctrl.value.isInitialized)
                    ? null
                    : () => _setTorch(!_torchOn),
                icon: Icon(
                  _torchOn ? Icons.flashlight_off : Icons.flashlight_on,
                ),
                label: Text(_torchOn ? 'Apagar (manual)' : 'Prender (manual)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;
  const _StatusTile({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: monospace ? 'monospace' : null,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
