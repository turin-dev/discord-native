import 'dart:async';

import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/presentation/attachment_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  late _FakeVideoPlayerPlatform platform;

  setUp(() {
    platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  test('attachment 크기로 안전한 영상 비율을 계산한다', () {
    expect(
      discordAttachmentAspectRatio(_attachment(width: 1920, height: 1080)),
      16 / 9,
    );
    expect(
      discordAttachmentAspectRatio(_attachment(width: 0, height: 0)),
      16 / 9,
    );
    expect(
      discordAttachmentAspectRatio(_attachment(width: 10, height: 100)),
      0.5,
    );
    expect(
      discordAttachmentAspectRatio(_attachment(width: 100, height: 10)),
      2.4,
    );
  });

  testWidgets('HTTPS가 아닌 영상 URL은 platform 호출 전에 거부한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DiscordAttachmentVideoPlayer(
            attachment: _attachment(proxyUrl: 'http://example.com/video.mp4'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('영상을 재생할 수 없습니다.'), findsOneWidget);
    expect(platform.dataSources, isEmpty);
  });

  testWidgets('HTTPS 영상을 초기화하고 재생·음소거·전체 화면을 제어한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: buildDiscordAttachmentVideoPlayer(_attachment())),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(platform.dataSources.single.uri, contains('media.discordapp.net'));
    expect(platform.dataSources.single.httpHeaders['Range'], 'bytes=0-');
    expect(find.byTooltip('재생'), findsOneWidget);

    await tester.tap(find.byTooltip('재생'));
    await tester.pump();
    expect(platform.calls, contains('play'));

    await tester.tap(find.byTooltip('음소거'));
    await tester.pump();
    expect(platform.volumes, contains(0));

    await tester.tap(find.byTooltip('전체 화면'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('전체 화면 닫기'), findsOneWidget);
    await tester.tap(find.byTooltip('전체 화면 닫기'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final StreamController<VideoEvent> _events = StreamController<VideoEvent>();
  final List<String> calls = <String>[];
  final List<DataSource> dataSources = <DataSource>[];
  final List<double> volumes = <double>[];

  @override
  Future<void> init() async => calls.add('init');

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    dataSources.add(options.dataSource);
    scheduleMicrotask(
      () => _events.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(1280, 720),
          duration: const Duration(minutes: 1),
        ),
      ),
    );
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    calls.add('seekTo');
  }

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> dispose(int playerId) async => calls.add('dispose');
}

DiscordAttachment _attachment({
  int? width = 1280,
  int? height = 720,
  String proxyUrl = 'https://media.discordapp.net/video.mp4',
}) {
  return DiscordAttachment(
    id: 'video',
    filename: 'video.mp4',
    url: proxyUrl,
    proxyUrl: proxyUrl,
    size: 1024,
    contentType: 'video/mp4',
    width: width,
    height: height,
  );
}
