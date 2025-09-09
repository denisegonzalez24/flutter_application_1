// lib/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WebSocketService {
  WebSocketService({
    required this.url,
    this.headers = const {},
    this.pingInterval = const Duration(seconds: 20),
    this.maxBackoffSeconds = 10,
  });

  final Uri url;
  final Map<String, String> headers;
  final Duration pingInterval;
  final int maxBackoffSeconds;

  WebSocket? _ws;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _manuallyClosed = false;

  // ➜ Stream broadcast para que varios módulos se suscriban
  final _messageCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageCtrl.stream;

  // Eventos opcionales
  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(Object error)? onError;

  bool get isConnected => _ws != null;
  String genId() => 't_${DateTime.now().millisecondsSinceEpoch}';

  Future<void> connect() async {
    _manuallyClosed = false;
    _cancelReconnect();
    try {
      _ws = await WebSocket.connect(url.toString(), headers: headers);
      _ws?.pingInterval = pingInterval;
      onConnected?.call();

      _sub = _ws!.listen(
        _handleRaw,
        onError: (e) {
          onError?.call(e);
          _scheduleReconnect();
        },
        onDone: _onDone,
        cancelOnError: true,
      );
    } catch (e) {
      onError?.call(e);
      _scheduleReconnect();
    }
  }

  void _handleRaw(dynamic data) {
    try {
      if (data is List<int>) data = utf8.decode(data, allowMalformed: true);
      if (data is! String) return;
      final trimmed = data.trim();
      final decoded = json.decode(trimmed);
      if (decoded is Map<String, dynamic>) {
        _messageCtrl.add(decoded); // ➜ Publicamos para todos los listeners
      } else {
        onError?.call('WS: mensaje no es JSON objeto');
      }
    } catch (e) {
      onError?.call('WS parse error: $e');
    }
  }

  void _onDone() {
    onDisconnected?.call();
    if (_manuallyClosed) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectAttempt++;
    final backoff = _backoffSeconds(_reconnectAttempt);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: backoff), connect);
  }

  int _backoffSeconds(int attempt) {
    final v = 1 << (attempt - 1);
    return v > maxBackoffSeconds ? maxBackoffSeconds : v;
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
  }

  void send(Map<String, dynamic> payload) {
    final ws = _ws;
    if (ws == null) return;
    try {
      ws.add(json.encode(payload));
    } catch (e) {
      onError?.call('WS send error: $e');
    }
  }

  Future<void> close() async {
    _manuallyClosed = true;
    _cancelReconnect();
    await _sub?.cancel();
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
  }
}
