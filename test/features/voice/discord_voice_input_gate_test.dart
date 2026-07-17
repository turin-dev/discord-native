import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_voice_input_gate.dart';
import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordVoiceInputGate', () {
    test('VAD 임계값 이상의 frame을 보내고 hangover 뒤 중지한다', () {
      final gate = DiscordVoiceInputGate(
        voiceActivityThreshold: 0.1,
        hangoverFrames: 2,
      );

      expect(
        gate.evaluate(
          Int16List.fromList([20000, -20000]),
          inputMode: DiscordVoiceInputMode.voiceActivity,
          pushToTalkPressed: false,
          currentlySpeaking: false,
        ),
        DiscordVoiceInputDecision.send,
      );
      expect(
        gate.evaluate(
          Int16List.fromList([0, 0]),
          inputMode: DiscordVoiceInputMode.voiceActivity,
          pushToTalkPressed: false,
          currentlySpeaking: true,
        ),
        DiscordVoiceInputDecision.send,
      );
      expect(
        gate.evaluate(
          Int16List.fromList([0, 0]),
          inputMode: DiscordVoiceInputMode.voiceActivity,
          pushToTalkPressed: false,
          currentlySpeaking: true,
        ),
        DiscordVoiceInputDecision.send,
      );
      expect(
        gate.evaluate(
          Int16List.fromList([0, 0]),
          inputMode: DiscordVoiceInputMode.voiceActivity,
          pushToTalkPressed: false,
          currentlySpeaking: true,
        ),
        DiscordVoiceInputDecision.stop,
      );
    });

    test('PTT는 누른 동안만 전송하고 release 시 중지한다', () {
      final gate = DiscordVoiceInputGate();
      final frame = Int16List.fromList([1000, -1000]);

      expect(
        gate.evaluate(
          frame,
          inputMode: DiscordVoiceInputMode.pushToTalk,
          pushToTalkPressed: false,
          currentlySpeaking: false,
        ),
        DiscordVoiceInputDecision.drop,
      );
      expect(
        gate.evaluate(
          frame,
          inputMode: DiscordVoiceInputMode.pushToTalk,
          pushToTalkPressed: true,
          currentlySpeaking: false,
        ),
        DiscordVoiceInputDecision.send,
      );
      expect(
        gate.evaluate(
          frame,
          inputMode: DiscordVoiceInputMode.pushToTalk,
          pushToTalkPressed: false,
          currentlySpeaking: true,
        ),
        DiscordVoiceInputDecision.stop,
      );
    });

    test('임계값과 frame 경계를 검증한다', () {
      expect(
        () => DiscordVoiceInputGate(voiceActivityThreshold: 1.1),
        throwsFormatException,
      );
      expect(
        () => DiscordVoiceInputGate().evaluate(
          Int16List(0),
          inputMode: DiscordVoiceInputMode.voiceActivity,
          pushToTalkPressed: false,
          currentlySpeaking: false,
        ),
        throwsFormatException,
      );
    });
  });
}
