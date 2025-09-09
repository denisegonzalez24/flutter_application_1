// lib/app/notification_sound_controller.dart
import 'dart:async';
import '../services/sound_service.dart';
import '../services/websocket_service.dart';

class NotificationSoundController {
  NotificationSoundController({required this.ws, required this.sound}) {
    _sub = ws.messages.listen(_handle);
  }

  final WebSocketService ws;
  final SoundService sound;

  StreamSubscription<Map<String, dynamic>>? _sub;

  void _handle(Map<String, dynamic> m) async {
    // Caso 1: protocolo con "op: notify"
    if (m['op'] == 'notify') {
      final tipo = (m['type'] ?? m['nivel'] ?? 'pitido').toString();
      await sound.play(tipo);
      // (Opcional) ack
      final id = (m['id'] ?? ws.genId()).toString();
      ws.send({'id': id, 'op': 'notify', 'ok': 'true'});
      return;
    }

    // Caso 2: protocolo anterior con "cmd: sound"
    if (m['cmd'] == 'sound') {
      final args = m['args'];
      final tipo = (args is Map) ? (args['tipo'] as String?) : null;
      await sound.play(tipo);
      final id = (m['id'] ?? ws.genId()).toString();
      ws.send({
        'id': id,
        'cmd': 'sound',
        'ok': 'true',
        if (tipo != null) 'tipo': tipo,
      });
      return;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await sound.stop();
  }
}
