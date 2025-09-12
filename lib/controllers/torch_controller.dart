// lib/controllers/torch_controller.dart
import 'dart:convert';


try {
final trimmed = data.trim();
dynamic decoded;
try { decoded = json.decode(trimmed); } catch (_) { decoded = null; }


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
camera.setTorch(desired).whenComplete(() {
final ok = camera.lastError == null;
torchOn.value = camera.torchOn;
_sendTorchAck(requestId: reqId, ok: ok, err: ok ? null : camera.lastError);
if (!ok) errorText.value = camera.lastError;
});
} else {
_sendTorchAck(requestId: reqId, ok: false, err: 'payload invalido: on');
}
return;
}


// OP desconocida
ws.sendJson({
'id': reqId ?? _genAckId(),
'op': '$op',
'ok': 'false',
'err': 'op desconocida',
});
return;
}


// Texto plano
final norm = trimmed.toLowerCase();
final desired = _parseDesiredFromText(norm);
if (desired != null) {
camera.setTorch(desired).whenComplete(() {
final ok = camera.lastError == null;
torchOn.value = camera.torchOn;
_sendTorchAck(requestId: null, ok: ok, err: ok ? null : camera.lastError);
if (!ok) errorText.value = camera.lastError;
});
} else {
errorText.value = 'WS msg desconocido: "$data"';
}
} catch (e) {
errorText.value = 'Error parseando WS: $e';
}
}
}