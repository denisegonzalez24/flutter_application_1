import 'package:flutter/material.dart';
return Scaffold(
appBar: AppBar(title: const Text('Torch con WebSocket')),
body: Padding(
padding: const EdgeInsets.all(12.0),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
ValueListenableBuilder(
valueListenable: _controller.cameraReady,
builder: (context, bool ready, _) => StatusTile(
label: 'Cámara',
value: ready ? 'Inicializada' : 'No lista',
),
),
const SizedBox(height: 8),
ValueListenableBuilder(
valueListenable: _controller.torchOn,
builder: (context, bool on, _) => StatusTile(
label: 'Linterna',
value: on ? 'Encendida' : 'Apagada',
),
),
const SizedBox(height: 8),
StatusTile(label: 'WS URL', value: _controller.socketUri.toString(), monospace: true),
const SizedBox(height: 8),
ValueListenableBuilder(
valueListenable: _controller.errorText,
builder: (context, String? err, _) => err == null || err.isEmpty
? const SizedBox.shrink()
: Container(
width: double.infinity,
padding: const EdgeInsets.all(12),
decoration: BoxDecoration(
color: Colors.red.withOpacity(0.08),
borderRadius: BorderRadius.circular(8),
border: Border.all(color: Colors.red.withOpacity(0.3)),
),
child: Text(err, style: const TextStyle(color: Colors.red)),
),
),
const Spacer(),
Center(
child: ValueListenableBuilder(
valueListenable: _controller.cameraReady,
builder: (context, bool ready, _) {
return ValueListenableBuilder(
valueListenable: _controller.torchOn,
builder: (context, bool on, __) {
return ElevatedButton.icon(
onPressed: ready ? () => _controller.toggleTorch() : null,
icon: Icon(on ? Icons.flashlight_off : Icons.flashlight_on),
label: Text(on ? 'Apagar (manual)' : 'Prender (manual)'),
);
},
);
},
),
),
],
),
),
);
}
}