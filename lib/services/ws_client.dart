// lib/services/ws_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Cliente WebSocket con reconexión exponencial simple.
/// IMPORTANTE: usa dart:io => **no** funciona en web (Chrome). Para Web,
/// reemplazá por web_socket_channel.
class WsClient {
  WsClient({
    required this.baseUrl,
    this.path = '/ws',
    this.token,
    this.pingInterval = const Duration(seconds: 20),
    this.maxBackoffSeconds = 10,
  });

  final String baseUrl;
  final String path;
  final String? token;
  final Duration pingInterval;
  final int maxBackoffSeconds;

  WebSocket? _ws;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  int _attempt = 0;
  bool _manualClose = false;

  /// Callbacks
  void Function()? onConnected;
  void Function()? onDisconnected;
  void Function(Object error)? onError;
  void Function(String text)? onText;

  Uri get uri => Uri.parse(baseUrl).replace(path: path);

  Future<void> connect() async {
    _manualClose = false;
    _cancelReconnect();
    try {
      final headers = <String, dynamic>{};
      if (token != null && token!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      _ws = await WebSocket.connect(uri.toString(), headers: headers);
      _ws!.pingInterval = pingInterval;
      _attempt = 0;
      onConnected?.call();

      _sub = _ws!.listen(
        (data) {
          if (data is List<int>) {
            try {
              data = utf8.decode(data, allowMalformed: true);
            } catch (_) {
              return;
            }
          }
          if (data is String) onText?.call(data);
        },
        onDone: _handleDone,
        onError: (e) {
          onError?.call(e);
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      onError?.call(e);
      _scheduleReconnect();
    }
  }

  void sendJson(Map<String, dynamic> payload) {
    final socket = _ws;
    if (socket == null) return; // evita "Cannot send Null"
    try {
      socket.add(jsonEncode(payload));
    } catch (e) {
      onError?.call(e);
    }
  }

  void _handleDone() {
    if (_manualClose) return;
    _scheduleReconnect();
    onDisconnected?.call();
  }

  void _scheduleReconnect() {
    _attempt++;
    final seconds = _attempt >= 1 ? (1 << (_attempt - 1)) : 1; // 1,2,4,8...
    final delay = Duration(
      seconds: seconds > maxBackoffSeconds ? maxBackoffSeconds : seconds,
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _attempt = 0;
  }

  Future<void> close() async {
    _manualClose = true;
    _cancelReconnect();
    await _sub?.cancel();
    _sub = null;
    try {
      await _ws?.close();
    } catch (_) {}
    _ws = null;
  }
}
