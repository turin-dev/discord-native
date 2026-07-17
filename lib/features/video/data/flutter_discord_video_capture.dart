import 'package:discord_native/features/video/data/discord_video_capture.dart';
import 'package:discord_native/features/video/domain/discord_video_protocol.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract interface class DiscordVideoCaptureDevice {
  Future<DiscordVideoCaptureResource> openCamera({
    required int width,
    required int height,
    required int framesPerSecond,
  });

  Future<DiscordVideoCaptureResource> openScreen({
    required int width,
    required int height,
    required int framesPerSecond,
  });
}

final class DiscordVideoCaptureResource {
  DiscordVideoCaptureResource({
    required this.sourceId,
    required this.preview,
    required Future<void> Function() release,
  }) : _release = release {
    if (sourceId.trim().isEmpty) {
      throw const FormatException('Video capture source ID가 비어 있습니다.');
    }
  }

  final String sourceId;
  final Object preview;
  final Future<void> Function() _release;

  Future<void> release() => _release();
}

final class FlutterDiscordVideoCapture
    implements DiscordVideoCaptureController {
  FlutterDiscordVideoCapture({DiscordVideoCaptureDevice? device})
    : _device = device ?? const FlutterWebRtcVideoCaptureDevice();

  static const int cameraWidth = 1280;
  static const int cameraHeight = 720;
  static const int cameraFramesPerSecond = 30;
  static const int screenWidth = 1920;
  static const int screenHeight = 1080;
  static const int screenFramesPerSecond = 30;

  final DiscordVideoCaptureDevice _device;
  _FlutterDiscordVideoCaptureSession? _activeSession;

  @override
  DiscordVideoCaptureSession? get activeSession => _activeSession;

  MediaStream? get previewStream => _activeSession?.preview as MediaStream?;

  @override
  Future<DiscordVideoCaptureSession> startCamera() async {
    _ensureIdle();
    final resource = await _device.openCamera(
      width: cameraWidth,
      height: cameraHeight,
      framesPerSecond: cameraFramesPerSecond,
    );
    return _activate(
      resource,
      DiscordVideoSource.camera(
        sourceId: resource.sourceId,
        width: cameraWidth,
        height: cameraHeight,
        framesPerSecond: cameraFramesPerSecond,
      ),
    );
  }

  @override
  Future<DiscordVideoCaptureSession> startScreen() async {
    _ensureIdle();
    final resource = await _device.openScreen(
      width: screenWidth,
      height: screenHeight,
      framesPerSecond: screenFramesPerSecond,
    );
    return _activate(
      resource,
      DiscordVideoSource.screen(
        sourceId: resource.sourceId,
        width: screenWidth,
        height: screenHeight,
        framesPerSecond: screenFramesPerSecond,
      ),
    );
  }

  @override
  Future<void> setPaused(bool paused) async {
    final preview = _activeSession?.preview;
    if (preview is! MediaStream) {
      throw StateError('일시 정지할 Video capture가 없습니다.');
    }
    final tracks = List<MediaStreamTrack>.unmodifiable(
      preview.getVideoTracks(),
    );
    if (tracks.isEmpty) {
      throw StateError('일시 정지할 video track이 없습니다.');
    }
    for (final track in tracks) {
      track.enabled = !paused;
    }
  }

  @override
  Future<void> stop() async {
    final session = _activeSession;
    if (session == null) {
      return;
    }
    _activeSession = null;
    await session.release();
  }

  DiscordVideoCaptureSession _activate(
    DiscordVideoCaptureResource resource,
    DiscordVideoSource source,
  ) {
    final session = _FlutterDiscordVideoCaptureSession(
      resource: resource,
      source: source,
    );
    _activeSession = session;
    return session;
  }

  void _ensureIdle() {
    if (_activeSession != null) {
      throw StateError('Video capture가 이미 활성 상태입니다.');
    }
  }
}

final class _FlutterDiscordVideoCaptureSession
    implements DiscordVideoCaptureSession {
  const _FlutterDiscordVideoCaptureSession({
    required DiscordVideoCaptureResource resource,
    required this.source,
  }) : _resource = resource;

  final DiscordVideoCaptureResource _resource;

  @override
  final DiscordVideoSource source;

  @override
  Object get preview => _resource.preview;

  Future<void> release() => _resource.release();
}

final class FlutterWebRtcVideoCaptureDevice
    implements DiscordVideoCaptureDevice {
  const FlutterWebRtcVideoCaptureDevice();

  @override
  Future<DiscordVideoCaptureResource> openCamera({
    required int width,
    required int height,
    required int framesPerSecond,
  }) async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': false,
      'video': {
        'width': {'ideal': width},
        'height': {'ideal': height},
        'frameRate': {'ideal': framesPerSecond},
      },
    });
    return _resourceForStream(stream, '카메라');
  }

  @override
  Future<DiscordVideoCaptureResource> openScreen({
    required int width,
    required int height,
    required int framesPerSecond,
  }) async {
    final stream = await navigator.mediaDevices.getDisplayMedia({
      'audio': false,
      'video': {
        'width': {'ideal': width},
        'height': {'ideal': height},
        'frameRate': {'ideal': framesPerSecond},
      },
    });
    return _resourceForStream(stream, '화면 공유');
  }
}

Future<DiscordVideoCaptureResource> _resourceForStream(
  MediaStream stream,
  String label,
) async {
  final tracks = List<MediaStreamTrack>.unmodifiable(stream.getVideoTracks());
  if (tracks.isEmpty) {
    await stream.dispose();
    throw FormatException('$label video track을 열 수 없습니다.');
  }
  final sourceId = tracks.first.id?.trim();
  if (sourceId == null || sourceId.isEmpty) {
    await _releaseStream(stream, tracks);
    throw FormatException('$label video track ID가 비어 있습니다.');
  }
  return DiscordVideoCaptureResource(
    sourceId: sourceId,
    preview: stream,
    release: () => _releaseStream(stream, tracks),
  );
}

Future<void> _releaseStream(
  MediaStream stream,
  List<MediaStreamTrack> tracks,
) async {
  for (final track in tracks) {
    await track.stop();
  }
  await stream.dispose();
}
