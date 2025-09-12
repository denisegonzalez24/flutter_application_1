// lib/controllers/torch_controller.dart
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/ws_client.dart';
import '../services/camera_service.dart';
import '../config.dart';

/// Orquesta cámara + WebSocket y expone estados mínimos a la UI.
class TorchController {
  TorchController()
    : ws = WsClient(baseUrl: kWsBase, path: kWsPath, token: kToken);

  final WsClient ws;
  final CameraService camera = CameraService();

  // Estados que la UI puede observar con ValueListenableBuilder si querés
  final ValueNotifier<bool> cameraReady = ValueNotifier(false);
  final ValueNotifier<bool> torchOn = ValueNotifier(false);
  final ValueNotifier<String?> errorText = ValueNotifier(null);
  final ValueNotifier<String?> wsText = ValueNotifier(null);

  String get wsUrl => ws.uri.toString();

  Future<void> init() async {
    try {
      await camera.init();
      cameraReady.value = true;
      torchOn.value = camera.torchOn;
    } catch (_) {
      errorText.value = camera.lastError;
    }

    ws.onConnected = () => errorText.value = null;
    ws.onDisconnected = () {};
    ws.onError = (e) => errorText.value = 'WS error: $e';
    ws.onText = _onWsText;

    await ws.connect();
  }

  Future<void> dispose() async {
    await ws.close();
    await camera.dispose();
  }

  // ===== Protocolo =====
  String _genAckId() => 't_${DateTime.now().millisecondsSinceEpoch}';

  void _sendPingEcho({String? requestId, dynamic ts}) {
    ws.sendJson({
      'id': requestId ?? _genAckId(),
      'op': 'ping',
      'ok': 'true',
      if (ts != null) 'ts': ts,
      'now': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _sendTorchAck({String? requestId, required bool ok, String? err}) {
    ws.sendJson({
      'id': requestId ?? _genAckId(),
      'op': 'torch',
      'ok': ok ? 'true' : 'false',
      if (err != null) 'err': err,
    });
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

  void _onWsText(String data) {
    try {
      final trimmed = data.trim();
      dynamic decoded;
      try {
        decoded = json.decode(trimmed);
      } catch (_) {
        decoded = null;
      }

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
            if (s == 'true' ||
                s == 'on' ||
                s == '1' ||
                s == 'encender' ||
                s == 'prender')
              desired = true;
            if (s == 'false' || s == 'off' || s == '0' || s == 'apagar')
              desired = false;
          }

          if (desired != null) {
            camera.setTorch(desired).whenComplete(() {
              final ok = camera.lastError == null;
              torchOn.value = camera.torchOn;
              _sendTorchAck(
                requestId: reqId,
                ok: ok,
                err: ok ? null : camera.lastError,
              );
              if (!ok) errorText.value = camera.lastError;
            });
          } else {
            _sendTorchAck(
              requestId: reqId,
              ok: false,
              err: 'payload invalido: on',
            );
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
          _sendTorchAck(
            requestId: null,
            ok: ok,
            err: ok ? null : camera.lastError,
          );
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
