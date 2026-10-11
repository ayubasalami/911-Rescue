import 'dart:io' show Platform;

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
  Future<void>? _configured;

  /// iOS's default audio session is muted by the ring/silent switch, so
  /// with the phone on silent every instruction was silently dropped. A
  /// playback session in voice-prompt mode speaks regardless, the way
  /// navigation apps do, and ducks (lowers) any music instead of stopping
  /// it. Android needs none of this.
  Future<void> _configure() async {
    if (!Platform.isIOS) return;
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.duckOthers,
      IosTextToSpeechAudioCategoryOptions.interruptSpokenAudioAndMixWithOthers,
    ], IosTextToSpeechAudioMode.voicePrompt);
  }

  Future<void> speak(String instruction) async {
    if (instruction.isEmpty) return;
    await (_configured ??= _configure());
    await _tts.stop();
    await _tts.speak(instruction);
  }

  Future<void> stop() => _tts.stop();
}
