import 'dart:async';

import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';

Future<void> dispatchGlobalPushToTalk({
  required DiscordVoiceMediaState media,
  required bool pressed,
  required FutureOr<void> Function(bool pressed) apply,
}) async {
  final shouldApply =
      shouldMonitorGlobalPushToTalk(media) &&
      media.pushToTalkPressed != pressed;
  if (!shouldApply) {
    return;
  }
  await apply(pressed);
}

bool shouldMonitorGlobalPushToTalk(DiscordVoiceMediaState media) {
  return media.phase == DiscordVoiceMediaPhase.active &&
      media.inputMode == DiscordVoiceInputMode.pushToTalk;
}
