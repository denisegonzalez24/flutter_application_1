import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  CameraDescription? _camera;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool _torchOn = false;
  bool get torchOn => _torchOn;

  Future<void> initialize() async {
    if (isInitialized) return;
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
    _controller = ctrl;
  }

  Future<void> setTorch(bool on) async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    await ctrl.setFlashMode(on ? FlashMode.torch : FlashMode.off);
    _torchOn = on;
  }

  CameraController? get controller => _controller;

  Future<void> dispose() async {
    try {
      await _controller?.dispose();
    } finally {
      _controller = null;
      _camera = null;
      _torchOn = false;
    }
  }
}
