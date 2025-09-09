import 'dart:convert';
void _onWsText(String data) {
try {
final trimmed = data.trim();
dynamic decoded;
try { decoded = json.decode(trimmed); } catch (_) { decoded = null; }


// JSON { id, op, ... }
if (decoded is Map) {
final op = decoded['op'];
final reqId = decoded['id'] as String?;


if (op == 'ping') {
_sendPingEcho(requestId: reqId, ts: decoded['ts']);
return;
}
if (op == 'torch') {
final val = decoded['on'];
bool? desired;
if (val is bool) desired = val;
if (val is num) desired = val != 0;
if (val is String) {
final s = val.toLowerCase();
if (s == 'true' || s == 'on' || s == '1' || s == 'encender' || s == 'prender') desired = true;
if (s == 'false' || s == 'off' || s == '0' || s == 'apagar') desired = false;
}


if (desired != null) {
_camera.setTorch(desired).whenComplete(() {
final ok = _camera.lastError.value == null;
_sendTorchAck(requestId: reqId, ok: ok, err: ok ? null : _camera.lastError.value);
});
} else {
_sendTorchAck(requestId: reqId, ok: false, err: 'payload invalido: on');
}
return;
}


// OP desconocida
_ws.sendJson({
'id': reqId ?? _genAckId(),
'op': '$op',
'ok': 'false',
'err': 'op desconocida',
});
return;
}


// Fallback texto plano "on"/"off"
final norm = trimmed.toLowerCase();
if (_isOnWord(norm)) {
_camera.setTorch(true).whenComplete(() {
_sendTorchAck(requestId: null, ok: _camera.lastError.value == null, err: _camera.lastError.value);
});
} else if (_isOffWord(norm)) {
_camera.setTorch(false).whenComplete(() {
_sendTorchAck(requestId: null, ok: _camera.lastError.value == null, err: _camera.lastError.value);
});
} else {
errorText.value = 'WS msg desconocido: "$data"';
}
} catch (e) {
errorText.value = 'Error parseando WS: $e';
}
}
}