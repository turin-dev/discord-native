import 'dart:math';
import 'dart:typed_data';

import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';

enum DiscordVoiceInputDecision { send, drop, stop }

final class DiscordVoiceInputGate {
  DiscordVoiceInputGate({
    this.voiceActivityThreshold = 0.015,
    this.hangoverFrames = 10,
  }) {
    if (!voiceActivityThreshold.isFinite ||
        voiceActivityThreshold < 0 ||
        voiceActivityThreshold > 1) {
      throw const FormatException('Voice activity 임계값은 0~1 범위여야 합니다.');
    }
    if (hangoverFrames < 0 || hangoverFrames > 50) {
      throw const FormatException('Voice activity hangover 범위가 올바르지 않습니다.');
    }
  }

  final double voiceActivityThreshold;
  final int hangoverFrames;
  int _silentFrameCount = 0;

  DiscordVoiceInputDecision evaluate(
    Int16List frame, {
    required DiscordVoiceInputMode inputMode,
    required bool pushToTalkPressed,
    required bool currentlySpeaking,
  }) {
    if (frame.isEmpty) {
      throw const FormatException('Voice input frame이 비어 있습니다.');
    }
    if (inputMode == DiscordVoiceInputMode.pushToTalk) {
      _silentFrameCount = 0;
      if (pushToTalkPressed) {
        return DiscordVoiceInputDecision.send;
      }
      return currentlySpeaking
          ? DiscordVoiceInputDecision.stop
          : DiscordVoiceInputDecision.drop;
    }
    if (_normalizedRms(frame) >= voiceActivityThreshold) {
      _silentFrameCount = 0;
      return DiscordVoiceInputDecision.send;
    }
    if (!currentlySpeaking) {
      _silentFrameCount = 0;
      return DiscordVoiceInputDecision.drop;
    }
    if (_silentFrameCount < hangoverFrames) {
      _silentFrameCount += 1;
      return DiscordVoiceInputDecision.send;
    }
    _silentFrameCount = 0;
    return DiscordVoiceInputDecision.stop;
  }

  void reset() {
    _silentFrameCount = 0;
  }
}

double _normalizedRms(Int16List frame) {
  var sumOfSquares = 0.0;
  for (final sample in frame) {
    final normalized = sample / 32768;
    sumOfSquares += normalized * normalized;
  }
  return sqrt(sumOfSquares / frame.length);
}
