import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_network_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_ui_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/workspace_voice_controls.dart';
import 'package:discord_native/features/video/domain/discord_video_ui_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  testWidgets('음성 채널과 참가자를 표시하고 join을 요청한다', (tester) async {
    String? joinedChannelId;
    (String, double)? volumeChange;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceChannelTile(
            channel: const DiscordChannel(
              id: '200000000000000002',
              guildId: '100000000000000001',
              name: '일반 음성',
              type: 2,
              position: 0,
            ),
            active: false,
            participants: const [
              DiscordVoiceParticipant(
                guildId: '100000000000000001',
                channelId: '200000000000000002',
                userId: '300000000000000003',
                sessionId: 'voice-session',
                deaf: false,
                mute: false,
                selfDeaf: false,
                selfMute: true,
                selfStream: false,
                selfVideo: false,
                suppress: false,
              ),
            ],
            participantNames: const {'300000000000000003': '테스트 사용자'},
            onJoin: (channelId) => joinedChannelId = channelId,
            onSetUserVolume: (userId, volume) {
              volumeChange = (userId, volume);
            },
          ),
        ),
      ),
    );

    expect(find.text('일반 음성'), findsOneWidget);
    expect(find.text('테스트 사용자'), findsOneWidget);
    expect(find.byIcon(Icons.mic_off), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('voice-channel-200000000000000002')),
    );
    expect(joinedChannelId, '200000000000000002');

    await tester.tap(
      find.byKey(const ValueKey('voice-volume-300000000000000003')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('150%'));
    expect(volumeChange, ('300000000000000003', 1.5));
  });

  testWidgets('연결 panel에서 mute, deafen, leave를 제어한다', (tester) async {
    bool? muted;
    bool? deafened;
    DiscordVoiceInputMode? inputMode;
    var leaveCount = 0;
    bool? cameraEnabled;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceConnectionPanel(
            state: DiscordVoiceUiState(
              voice: const DiscordVoiceState(
                phase: DiscordVoicePhase.ready,
                guildId: '100000000000000001',
                channelId: '200000000000000002',
              ),
              networkPhase: DiscordVoiceNetworkPhase.ready,
              media: const DiscordVoiceMediaState(
                phase: DiscordVoiceMediaPhase.active,
              ),
              video: const DiscordVideoUiState(),
            ),
            channelName: '일반 음성',
            onSetMuted: (value) => muted = value,
            onSetDeafened: (value) => deafened = value,
            onSetInputMode: (value) => inputMode = value,
            onPushToTalkPressed: (_) {},
            onSetCameraEnabled: (value) => cameraEnabled = value,
            onLeave: () => leaveCount += 1,
          ),
        ),
      ),
    );

    expect(find.text('음성 연결됨'), findsOneWidget);
    expect(find.text('일반 음성'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('voice-mute-button')));
    await tester.tap(find.byKey(const ValueKey('voice-deafen-button')));
    await tester.tap(find.byKey(const ValueKey('voice-leave-button')));
    await tester.tap(find.byKey(const ValueKey('voice-input-mode-button')));
    await tester.tap(find.byKey(const ValueKey('voice-camera-button')));

    expect(muted, isTrue);
    expect(deafened, isTrue);
    expect(leaveCount, 1);
    expect(inputMode, DiscordVoiceInputMode.pushToTalk);
    expect(cameraEnabled, isTrue);
  });

  testWidgets('PTT button은 pointer press와 release를 전달한다', (tester) async {
    final values = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceConnectionPanel(
            state: const DiscordVoiceUiState(
              voice: DiscordVoiceState(
                phase: DiscordVoicePhase.ready,
                guildId: '100000000000000001',
                channelId: '200000000000000002',
              ),
              networkPhase: DiscordVoiceNetworkPhase.ready,
              media: DiscordVoiceMediaState(
                phase: DiscordVoiceMediaPhase.active,
                inputMode: DiscordVoiceInputMode.pushToTalk,
              ),
            ),
            channelName: '일반 음성',
            onSetMuted: (_) {},
            onSetDeafened: (_) {},
            onSetInputMode: (_) {},
            onPushToTalkPressed: values.add,
            onSetCameraEnabled: (_) {},
            onLeave: () {},
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('voice-ptt-button'))),
    );
    await gesture.up();

    expect(values, [true, false]);
  });

  testWidgets('원격 사용자 video stream을 사용자별 tile로 표시한다', (tester) async {
    final stream = _FakeMediaStream('remote-stream');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceConnectionPanel(
            state: DiscordVoiceUiState(
              voice: const DiscordVoiceState(
                phase: DiscordVoicePhase.ready,
                guildId: '100000000000000001',
                channelId: '200000000000000002',
              ),
              networkPhase: DiscordVoiceNetworkPhase.ready,
              media: const DiscordVoiceMediaState(
                phase: DiscordVoiceMediaPhase.active,
              ),
              video: DiscordVideoUiState(
                remotePreviews: {'400000000000000004': stream},
              ),
            ),
            channelName: '일반 음성',
            onSetMuted: (_) {},
            onSetDeafened: (_) {},
            onSetInputMode: (_) {},
            onPushToTalkPressed: (_) {},
            onSetCameraEnabled: (_) {},
            onLeave: () {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('voice-remote-video-400000000000000004')),
      findsOneWidget,
    );
    expect(find.text('400000000000000004'), findsOneWidget);
  });

  testWidgets('Go Live 화면 공유를 시작하고 일시 정지한다', (tester) async {
    final screenStream = _FakeMediaStream('screen-stream');
    bool? screenShareEnabled;
    bool? screenPaused;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceConnectionPanel(
            state: const DiscordVoiceUiState(
              voice: DiscordVoiceState(
                phase: DiscordVoicePhase.ready,
                guildId: '100000000000000001',
                channelId: '200000000000000002',
              ),
              networkPhase: DiscordVoiceNetworkPhase.ready,
              video: DiscordVideoUiState(
                screenSharePhase: DiscordVideoPhase.active,
                screenStreamKey:
                    'guild:100000000000000001:200000000000000002:300000000000000003',
              ),
            ),
            channelName: '일반 음성',
            onSetMuted: (_) {},
            onSetDeafened: (_) {},
            onSetInputMode: (_) {},
            onPushToTalkPressed: (_) {},
            onSetCameraEnabled: (_) {},
            onSetScreenShareEnabled: (value) => screenShareEnabled = value,
            onSetScreenSharePaused: (value) => screenPaused = value,
            localScreenStream: screenStream,
            onLeave: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('voice-screen-preview')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('voice-screen-share-button')));
    await tester.tap(find.byKey(const ValueKey('voice-screen-pause-button')));

    expect(screenShareEnabled, isFalse);
    expect(screenPaused, isTrue);
  });

  testWidgets('방송 중인 참가자의 Go Live 시청을 요청한다', (tester) async {
    String? watchedStreamKey;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceChannelTile(
            channel: const DiscordChannel(
              id: '200000000000000002',
              guildId: '100000000000000001',
              name: '일반 음성',
              type: 2,
              position: 0,
            ),
            active: true,
            participants: const [
              DiscordVoiceParticipant(
                guildId: '100000000000000001',
                channelId: '200000000000000002',
                userId: '300000000000000003',
                sessionId: 'voice-session',
                deaf: false,
                mute: false,
                selfDeaf: false,
                selfMute: false,
                selfStream: true,
                selfVideo: false,
                suppress: false,
              ),
            ],
            participantNames: const {'300000000000000003': '방송 사용자'},
            onJoin: (_) {},
            onWatchStream: (streamKey) => watchedStreamKey = streamKey,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('voice-watch-stream-300000000000000003')),
    );

    expect(
      watchedStreamKey,
      'guild:100000000000000001:200000000000000002:300000000000000003',
    );
  });
}

final class _FakeMediaStream extends MediaStream {
  _FakeMediaStream(String id) : super(id, 'local');

  @override
  bool get active => true;

  @override
  Future<void> addTrack(
    MediaStreamTrack track, {
    bool addToNative = true,
  }) async {}

  @override
  Future<void> getMediaTracks() async {}

  @override
  List<MediaStreamTrack> getAudioTracks() => const [];

  @override
  List<MediaStreamTrack> getTracks() => const [];

  @override
  List<MediaStreamTrack> getVideoTracks() => const [];

  @override
  Future<void> removeTrack(
    MediaStreamTrack track, {
    bool removeFromNative = true,
  }) async {}
}
