import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

final voiceDirectionsServiceProvider = Provider<VoiceDirectionsService>(
  (ref) => VoiceDirectionsService(),
);

/// Speaks turn-by-turn instructions during Go to Help tracking — real
/// device TTS, matching the web platform's browser `speechSynthesis` voice
/// directions rather than a placeholder.
class VoiceDirectionsService {
  final _tts = FlutterTts();

  Future<void> speak(String instruction) async {
    if (instruction.isEmpty) return;
    await _tts.stop();
    await _tts.speak(instruction);
  }

  Future<void> stop() => _tts.stop();
}
