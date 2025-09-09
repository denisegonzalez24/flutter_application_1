// lib/services/sound_service.dart
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class SoundService {
  final FlutterRingtonePlayer _ringer = FlutterRingtonePlayer();

  Future<void> play(String? tipoRaw) async {
    final tipo = (tipoRaw ?? '').toLowerCase().trim();
    switch (tipo) {
      case 'muerte':
        await _ringer.playAlarm(looping: false, volume: 1.0, asAlarm: true);
        break;
      case 'alerta':
        await _ringer.playNotification(looping: false, volume: 1.0);
        break;
      case 'pitido':
      default:
        await SystemSound.play(SystemSoundType.click);
        break;
    }
  }

  Future<void> stop() => _ringer.stop();
}
