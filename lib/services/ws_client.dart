import 'dart:async';


_sub = _ws!.listen(
(data) {
// Normalizar binario a string
if (data is List<int>) {
data = utf8.decode(data, allowMalformed: true);
}
if (data is String) {
_events.add(WsTextMessage(data));
}
},
onDone: _onDone,
onError: (e) {
_events.add(WsError('WS error: $e'));
_scheduleReconnect();
},
cancelOnError: true,
);
} catch (e) {
_events.add(WsError('No se pudo conectar al WS: $e'));
_scheduleReconnect();
}
}


void _onDone() {
_events.add(WsClosed());
if (_manuallyClosed) return;
_scheduleReconnect();
}


void _scheduleReconnect() {
_reconnectAttempt++;
final backoff = _reconnectBackoffSeconds(_reconnectAttempt);
_reconnectTimer?.cancel();
_reconnectTimer = Timer(Duration(seconds: backoff), connect);
_events.add(WsError('Reconectando WS en ${backoff}s...'));
}


int _reconnectBackoffSeconds(int attempt) {
final v = 1 << (attempt - 1); // 1,2,4,8...
final max = kReconnectMaxDelay.inSeconds;
return v > max ? max : v;
}


void _cancelReconnect() {
_reconnectTimer?.cancel();
_reconnectTimer = null;
_reconnectAttempt = 0;
}


void sendJson(Map<String, dynamic> payload) {
final ws = _ws;
if (ws == null) return;
try {
ws.add(json.encode(payload));
} catch (e) {
_events.add(WsError('WS send error: $e'));
}
}


Future<void> close() async {
_manuallyClosed = true;
_cancelReconnect();
await _sub?.cancel();
_sub = null;
try {
await _ws?.close();
} catch (_) {}
_ws = null;
}
}