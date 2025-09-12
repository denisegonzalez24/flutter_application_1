import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/widgets/status_title.dart';

import '../../controllers/torch_controller.dart';
import '../widgets/status_tile.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ctrl.init();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ctrl.dispose();
    super.dispose();
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
              builder: (context, ready, _) => StatusTile(
                label: 'Cámara',
                value: ready ? 'Inicializada' : 'No lista',
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: ctrl.torchOn,
              builder: (context, on, _) => StatusTile(
                label: 'Linterna',
                value: on ? 'Encendida' : 'Apagada',
              ),
            ),
            const SizedBox(height: 8),
            StatusTile(label: 'WS URL', value: ctrl.wsUrl, monospace: true),
            const SizedBox(height: 8),
            ValueListenableBuilder<String?>(
              valueListenable: ctrl.errorText,
              builder: (context, err, _) => err == null
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
                builder: (context, on, _) => ElevatedButton.icon(
                  onPressed: () {
                    ctrl.camera.setTorch(!on).whenComplete(() {
                      ctrl.torchOn.value = ctrl.camera.torchOn;
                      if (ctrl.camera.lastError != null) {
                        ctrl.errorText.value = ctrl.camera.lastError;
                      }
                    });
                  },
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
s