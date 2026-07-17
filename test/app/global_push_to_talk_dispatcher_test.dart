import 'package:discord_native/app/global_push_to_talk_dispatcher.dart';
import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('전역 key polling은 active PTT 음성 세션에서만 필요하다', () {
    expect(
      shouldMonitorGlobalPushToTalk(
        const DiscordVoiceMediaState(
          phase: DiscordVoiceMediaPhase.active,
          inputMode: DiscordVoiceInputMode.pushToTalk,
        ),
      ),
      isTrue,
    );
    expect(
      shouldMonitorGlobalPushToTalk(const DiscordVoiceMediaState()),
      isFalse,
    );
  });

  test('활성 PTT 음성에서 달라진 press 상태만 전달한다', () async {
    final values = <bool>[];

    await dispatchGlobalPushToTalk(
      media: const DiscordVoiceMediaState(
        phase: DiscordVoiceMediaPhase.active,
        inputMode: DiscordVoiceInputMode.pushToTalk,
      ),
      pressed: true,
      apply: values.add,
    );
    await dispatchGlobalPushToTalk(
      media: const DiscordVoiceMediaState(
        phase: DiscordVoiceMediaPhase.active,
        inputMode: DiscordVoiceInputMode.pushToTalk,
        pushToTalkPressed: true,
      ),
      pressed: true,
      apply: values.add,
    );

    expect(values, [true]);
  });

  test('연결 전이거나 Voice Activity이면 전역 PTT를 무시한다', () async {
    final values = <bool>[];

    await dispatchGlobalPushToTalk(
      media: const DiscordVoiceMediaState(
        inputMode: DiscordVoiceInputMode.pushToTalk,
      ),
      pressed: true,
      apply: values.add,
    );
    await dispatchGlobalPushToTalk(
      media: const DiscordVoiceMediaState(phase: DiscordVoiceMediaPhase.active),
      pressed: true,
      apply: values.add,
    );

    expect(values, isEmpty);
  });
}
