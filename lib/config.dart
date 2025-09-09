const String kWsBase = 'wss://node2.liit.com.ar'; // sin /ws acá
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';


/// Service que encapsula el manejo de la cámara y el torch.
class CameraService {
CameraController? _controller;
CameraDescription? _camera;


final ValueNotifier<bool> torchOn = ValueNotifier(false);
final ValueNotifier<bool> isReady = ValueNotifier(false);
final ValueNotifier<String?> lastError = ValueNotifier(null);


CameraController? get controller => _controller;


Future<void> init() async {
try {
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
isReady.value = true;
lastError.value = null;
} catch (e) {
lastError.value = 'No se pudo inicializar la cámara: $e';
isReady.value = false;
}
}


Future<void> setTorch(bool turnOn) async {
final ctrl = _controller;
if (ctrl == null || !ctrl.value.isInitialized) return;
try {
await ctrl.setFlashMode(turnOn ? FlashMode.torch : FlashMode.off);
torchOn.value = turnOn;
lastError.value = null;
} on CameraException catch (e) {
lastError.value = 'Error torch: ${e.code} ${e.description ?? ""}';
} catch (e) {
lastError.value = 'Error torch: $e';
}
}


Future<void> dispose() async {
try {
await _controller?.dispose();
} finally {
_controller = null;
torchOn.value = false;
isReady.value = false;
}
}
}