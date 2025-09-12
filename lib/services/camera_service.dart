// lib/services/camera_service.dart
import 'package:camera/camera.dart';

/// Encapsula el manejo de cámara/linterna.
class CameraService {
  CameraController? _controller;
  bool torchOn = false;
  String? lastError;

  CameraController? get controller => _controller;
  bool get isReady => _controller?.value.isInitialized ?? false;

  Future<void> init() async {
    lastError = null;
    try {
      final cameras = await availableCameras();
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final ctrl = CameraController(
        cam,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await ctrl.initialize();
      _controller = ctrl;
    } on CameraException catch (e) {
      lastError = 'CameraException: ${e.code} ${e.description ?? ''}';
      rethrow;
    } catch (e) {
      lastError = 'Camera init error: $e';
      rethrow;
    }
  }

  Future<void> setTorch(bool on) async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    lastError = null;
    try {
      await ctrl.setFlashMode(on ? FlashMode.torch : FlashMode.off);
      torchOn = on;
    } on CameraException catch (e) {
      lastError = 'Torch error: ${e.code} ${e.description ?? ''}';
    } catch (e) {
      lastError = 'Torch error: $e';
    }
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
