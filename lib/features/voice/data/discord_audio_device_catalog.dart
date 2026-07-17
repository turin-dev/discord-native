import 'package:discord_native/features/voice/data/record_discord_microphone_capture.dart';
import 'package:discord_native/features/voice/data/soloud_discord_voice_playback.dart';
import 'package:discord_native/features/voice/domain/discord_audio_device.dart';

Future<DiscordAudioDeviceCatalog> loadDiscordAudioDeviceCatalog({
  RecordAudioBackend? inputBackend,
  SoloudPlaybackBackend? outputBackend,
}) async {
  final input = inputBackend ?? AudioRecorderBackend();
  final output = outputBackend ?? NativeSoloudPlaybackBackend();
  List<DiscordAudioDevice> inputDevices = const [];
  List<DiscordAudioDevice> outputDevices = const [];
  Object? inputError;
  Object? outputError;
  try {
    inputDevices = await input.listInputDevices();
  } on Object catch (error) {
    inputError = error;
  } finally {
    await input.dispose();
  }
  try {
    await output.initialize();
    outputDevices = output.listPlaybackDevices();
  } on Object catch (error) {
    outputError = error;
  }
  if (inputError != null && outputError != null) {
    throw StateError('오디오 장치 목록을 불러오지 못했습니다.');
  }
  return DiscordAudioDeviceCatalog(
    inputDevices: List.unmodifiable(inputDevices),
    outputDevices: List.unmodifiable(outputDevices),
  );
}
