import 'package:discord_native/features/video/domain/discord_video_protocol.dart';

abstract interface class DiscordVideoCaptureSession {
  DiscordVideoSource get source;

  Object? get preview;
}

abstract interface class DiscordVideoCaptureController {
  DiscordVideoCaptureSession? get activeSession;

  Future<DiscordVideoCaptureSession> startCamera();

  Future<DiscordVideoCaptureSession> startScreen();

  Future<void> setPaused(bool paused);

  Future<void> stop();
}
