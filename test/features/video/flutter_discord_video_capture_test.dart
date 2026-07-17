import 'package:discord_native/features/video/data/flutter_discord_video_capture.dart';
import 'package:discord_native/features/video/domain/discord_video_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterDiscordVideoCapture', () {
    test('camera resource를 source와 preview session으로 노출한다', () async {
      final device = _FakeCaptureDevice();
      final capture = FlutterDiscordVideoCapture(device: device);

      final session = await capture.startCamera();

      expect(session.source.kind, DiscordVideoSourceKind.camera);
      expect(session.source.sourceId, 'camera-track');
      expect(session.preview, same(device.preview));
      expect(capture.activeSession, same(session));
    });

    test('stop은 active session을 먼저 제거하고 resource를 한 번 정리한다', () async {
      final device = _FakeCaptureDevice();
      final capture = FlutterDiscordVideoCapture(device: device);
      await capture.startCamera();

      await capture.stop();
      await capture.stop();

      expect(capture.activeSession, isNull);
      expect(device.releaseCount, 1);
    });

    test('동시에 두 capture를 시작하지 않는다', () async {
      final capture = FlutterDiscordVideoCapture(device: _FakeCaptureDevice());
      await capture.startCamera();

      await expectLater(capture.startScreen(), throwsStateError);
    });
  });
}

final class _FakeCaptureDevice implements DiscordVideoCaptureDevice {
  final Object preview = Object();
  int releaseCount = 0;

  @override
  Future<DiscordVideoCaptureResource> openCamera({
    required int width,
    required int height,
    required int framesPerSecond,
  }) async {
    return DiscordVideoCaptureResource(
      sourceId: 'camera-track',
      preview: preview,
      release: () async => releaseCount += 1,
    );
  }

  @override
  Future<DiscordVideoCaptureResource> openScreen({
    required int width,
    required int height,
    required int framesPerSecond,
  }) async {
    return DiscordVideoCaptureResource(
      sourceId: 'screen-track',
      preview: preview,
      release: () async => releaseCount += 1,
    );
  }
}
