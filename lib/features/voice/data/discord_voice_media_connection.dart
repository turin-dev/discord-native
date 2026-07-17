import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';

abstract interface class DiscordVoiceMediaConnection {
  DiscordVoiceMediaState get state;

  Stream<DiscordVoiceMediaState> get states;

  Future<void> start();

  Future<void> setMuted(bool muted);

  Future<void> setDeafened(bool deafened);

  Future<void> setInputMode(DiscordVoiceInputMode inputMode);

  Future<void> setPushToTalkPressed(bool pressed);

  void setUserVolume(String remoteUserId, double volume);

  Future<void> stop();

  Future<void> dispose();
}
