import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const TorchCameraPage(),
    );
  }
}

class TorchCameraPage extends StatefulWidget {
  const TorchCameraPage({super.key});

  @override
  State<TorchCameraPage> createState() => _TorchCameraPageState();
}

class _TorchCameraPageState extends State<TorchCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraDescription? _camera;
  bool _torchOn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      // trasera si existe, sino cualquiera
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

      if (!mounted) return;
      setState(() {
        _controller = ctrl;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'No se pudo inicializar la cámara: $e');
    }
  }

  Future<void> _toggleTorch() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    try {
      if (_torchOn) {
        await ctrl.setFlashMode(FlashMode.off);
      } else {
        await ctrl.setFlashMode(FlashMode.torch);
      }
      setState(() => _torchOn = !_torchOn);
    } on CameraException catch (e) {
      setState(() => _error = 'Error torch: ${e.code} ${e.description ?? ""}');
    } catch (e) {
      setState(() => _error = 'Error torch: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    // Libera la cámara si la app se pausa, y la reabre al volver
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      ctrl.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;

    return Scaffold(
      appBar: AppBar(title: const Text('Torch con camera')),
      body: Column(
        children: [
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.withOpacity(0.1),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 8),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: (ctrl == null || !ctrl.value.isInitialized)
                  ? null
                  : _toggleTorch,
              icon: Icon(_torchOn ? Icons.flashlight_off : Icons.flashlight_on),
              label: Text(_torchOn ? 'Apagar linterna' : 'Prender linterna'),
            ),
          ),
        ],
      ),
    );
  }
}
