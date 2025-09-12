// lib/ui/pages/torch_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/widgets/status_title.dart';

import '../../controllers/torch_controller.dart';

class TorchPage extends StatefulWidget {
  const TorchPage({super.key});

  @override
  State<TorchPage> createState() => _TorchPageState();
}

class _TorchPageState extends State<TorchPage> with WidgetsBindingObserver {
  late final TorchController ctrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ctrl = TorchController();
    // Arranque
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ctrl.init();
      setState(() {}); // para pintar URL, etc.
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si quisieras pausar la cámara/ws aquí, podés extender el controller.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Torch con WebSocket')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: ctrl.cameraReady,
              builder: (_, ready, __) => StatusTile(
                label: 'Cámara',
                value: ready ? 'Inicializada' : 'No lista',
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: ctrl.torchOn,
              builder: (_, on, __) => StatusTile(
                label: 'Linterna',
                value: on ? 'Encendida' : 'Apagada',
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: ctrl.wsText,
              builder: (_, on, __) =>
                  StatusTile(label: on ?? 'asd', value: on ?? 'asd'),
            ),
            const SizedBox(height: 8),
            StatusTile(label: 'WS URL', value: ctrl.wsUrl, monospace: true),
            const SizedBox(height: 8),
            ValueListenableBuilder<String?>(
              valueListenable: ctrl.errorText,
              builder: (_, err, __) => err == null
                  ? const SizedBox.shrink()
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Text(
                        err,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
            ),
            const Spacer(),
            Center(
              child: ValueListenableBuilder<bool>(
                valueListenable: ctrl.torchOn,
                builder: (_, on, __) => ElevatedButton.icon(
                  onPressed: !ctrl.camera.isReady
                      ? null
                      : () => ctrl.camera.setTorch(!on).whenComplete(() {
                          ctrl.torchOn.value = ctrl.camera.torchOn;
                          if (ctrl.camera.lastError != null) {
                            ctrl.errorText.value = ctrl.camera.lastError;
                          }
                        }),
                  icon: Icon(on ? Icons.flashlight_off : Icons.flashlight_on),
                  label: Text(on ? 'Apagar (manual)' : 'Prender (manual)'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
