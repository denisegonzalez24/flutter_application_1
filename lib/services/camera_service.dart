// lib/services/ws_client.dart
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
final delay = Duration(seconds: seconds > maxBackoffSeconds ? maxBackoffSeconds : seconds);
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
try { await _ws?.close(); } catch (_) {}
_ws = null;
}
}