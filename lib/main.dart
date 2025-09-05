import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

// === Configuración de WebSocket ===
// - Emulador AVD: 'ws://10.0.2.2:13001/ws'
// - Dispositivo físico: 'ws://<IP_de_tu_PC>:13001/ws'
// - Tu server público (TLS):
const String kWsBase = 'wss://node2.liit.com.ar'; // sin /ws acá
const String kToken = '123456';

void main() async {
  // Evita issues de lifecycle/plugins en arranque
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Torch via WebSocket',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const TorchCameraPage(),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Inicializar cámara después del primer frame
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
      "id": requestId ?? _genAckId(), // eco del id del request
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
      // Normalizar binario a string
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

      // --- Caso JSON: { "id":"...", "op":"...", ... } ---
      if (decoded is Map) {
        final op = decoded["op"];
        final reqId = decoded["id"] as String?;

        // PING
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

        // TORCH
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

        // OP desconocida
        _sendWs({
          "id": reqId ?? _genAckId(),
          "op": "$op",
          "ok": "false",
          "err": "op desconocida",
        });
        return;
      }

      // --- Fallback: texto plano (para pruebas) ---
      // Soporta: "on", "off", "encender", "apagar", "true", "false",
      //          "1", "0", y también "torch on: false"/"torch on: true"
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

  /// Nuevo: interpreta texto libre tipo "torch on: false", "on=false",
  /// o directamente palabras sueltas ("on", "off", "true", "false", "1", "0").
  bool? _parseDesiredFromText(String s) {
    // Busca patrón on:=<valor>
    final m = RegExp(r'on\s*[:=]\s*([A-Za-z0-9_]+)').firstMatch(s);
    if (m != null) {
      final v = m.group(1)!.toLowerCase();
      if (_isOnWord(v)) return true;
      if (_isOffWord(v)) return false;
    }

    // Fallback: si todo el string es una palabra conocida
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
    final v = 1 << (attempt - 1); // 1,2,4,8...
    return v > 10 ? 10 : v; // tope 10s
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
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
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
