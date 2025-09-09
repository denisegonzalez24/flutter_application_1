// lib/app/torch_controller.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/camera_service.dart';
import '../services/websocket_service.dart';

class TorchController extends ChangeNotifier {
  TorchController({required this.camera, required this.ws}) {
    _sub = ws.messages.listen(_handle);
  }

  final CameraService camera;
  final WebSocketService ws;

  StreamSubscription<Map<String, dynamic>>? _sub;
  String? _error;
  String? get error => _error;

  bool get isCameraReady => camera.isInitialized;
  bool get torchOn => camera.torchOn;

  Future<void> init() async {
    _error = null;
    await camera.initialize();
    notifyListeners();
  }

  Future<void> toggleTorch() => setTorch(!torchOn);

  Future<void> setTorch(bool on) async {
    try {
      await camera.setTorch(on);
      _error = null;
    } catch (e) {
      _error = 'Error torch: $e';
    }
    notifyListeners();
  }

  void _handle(Map<String, dynamic> m) async {
    if (m['op'] != 'torch') return; // 👈 ignora todo lo que no sea torch

    final id = (m['id'] ?? ws.genId()).toString();
    final desired = _desiredFromAny(m['on']);
    if (desired == null) {
      ws.send({
        'id': id,
        'op': 'torch',
        'ok': 'false',
        'err': 'payload invalido: on',
      });
      return;
    }
    await setTorch(desired);
    ws.send({
      'id': id,
      'op': 'torch',
      'ok': (error == null).toString(),
      if (error != null) 'err': error,
    });
  }

  bool? _desiredFromAny(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      if (['true', 'on', '1', 'encender', 'prender', 'torch_on'].contains(s))
        return true;
      if (['false', 'off', '0', 'apagar', 'torch_off'].contains(s))
        return false;
    }
    return null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
