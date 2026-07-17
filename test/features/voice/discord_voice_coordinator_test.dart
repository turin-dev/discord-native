import 'dart:async';
import 'dart:typed_data';

import 'package:discord_native/core/gateway/discord_gateway_client.dart';
import 'package:discord_native/core/gateway/gateway_session_state.dart';
import 'package:discord_native/features/voice/data/discord_voice_coordinator.dart';
import 'package:discord_native/features/voice/data/discord_voice_media_engine.dart';
import 'package:discord_native/features/voice/domain/discord_voice_network_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_state.dart';
import 'package:discord_native/features/video/data/discord_video_capture.dart';
import 'package:discord_native/features/video/domain/discord_video_protocol.dart';
import 'package:discord_native/features/video/domain/discord_video_ui_state.dart';
import 'package:flutter_test/flutter_test.dart';

part 'discord_voice_coordinator_test_support.dart';

void main() {
  group('DiscordVoiceCoordinator', () {
    late _FakeGatewayConnection mainGateway;
    late _FakeVoiceNetworkConnection network;
    late _FakeVoiceNetworkConnection streamNetwork;
    late _FakeVoiceMediaConnection media;
    late _FakeVoiceMediaConnection streamMedia;
    late _FakeVoiceMediaConnection? replacementMedia;
    late _FakeVideoCapture videoCapture;
    late _FakeVideoCapture screenCapture;
    late DiscordVoiceCoordinator coordinator;

    setUp(() {
      mainGateway = _FakeGatewayConnection();
      network = _FakeVoiceNetworkConnection();
      streamNetwork = _FakeVoiceNetworkConnection();
      media = _FakeVoiceMediaConnection();
      streamMedia = _FakeVoiceMediaConnection();
      replacementMedia = null;
      videoCapture = _FakeVideoCapture();
      screenCapture = _FakeVideoCapture(
        source: const DiscordVideoSource.screen(
          sourceId: 'screen-track',
          width: 1920,
          height: 1080,
          framesPerSecond: 30,
        ),
      );
      coordinator = DiscordVoiceCoordinator(
        mainGateway: mainGateway,
        networkFactory: () => network,
        mediaFactory: (_) => replacementMedia ?? media,
        videoCapture: videoCapture,
        streamNetworkFactory: () => streamNetwork,
        streamMediaFactory: (_) => streamMedia,
        screenCapture: screenCapture,
      );
    });

    tearDown(() async {
      await coordinator.dispose();
      await mainGateway.disposeControllers();
      await network.disposeControllers();
      await streamNetwork.disposeControllers();
      await media.disposeControllers();
      await streamMedia.disposeControllers();
      await replacementMedia?.disposeControllers();
    });

    test('join handshake 뒤 Voice Gateway와 media engine을 순서대로 시작한다', () async {
      await coordinator.join(
        guildId: '100000000000000001',
        channelId: '200000000000000002',
      );

      expect(mainGateway.voiceUpdates.single, (
        guildId: '100000000000000001',
        channelId: '200000000000000002',
        selfMute: false,
        selfDeaf: false,
      ));
      expect(coordinator.state.voice.phase, DiscordVoicePhase.joining);

      coordinator.receiveGatewayEvent(
        _voiceServerEvent(),
        currentUserId: '300000000000000003',
      );
      coordinator.receiveGatewayEvent(
        _voiceStateEvent(),
        currentUserId: '300000000000000003',
      );
      await pumpEventQueue();

      expect(network.connectedCredentials, isNotNull);
      expect(network.connectedCredentials!.channelId, '200000000000000002');

      network.emit(
        DiscordVoiceNetworkState(
          phase: DiscordVoiceNetworkPhase.ready,
          ssrc: 4242,
          encryptionMode: 'aead_aes256_gcm_rtpsize',
          secretKey: Uint8List(32),
          daveProtocolVersion: 1,
        ),
      );
      await pumpEventQueue();

      expect(media.startCount, 1);
      expect(coordinator.state.networkPhase, DiscordVoiceNetworkPhase.ready);
      expect(coordinator.state.voice.phase, DiscordVoicePhase.ready);
      expect(coordinator.state.media.phase, DiscordVoiceMediaPhase.active);
    });

    test('mute와 deafen을 Main Gateway와 media engine에 함께 반영한다', () async {
      await _connectReady(coordinator, network);

      await coordinator.setMuted(true);
      await coordinator.setDeafened(true);
      await coordinator.setInputMode(DiscordVoiceInputMode.pushToTalk);
      await coordinator.setPushToTalkPressed(true);
      coordinator.setUserVolume('400000000000000004', 1.5);

      expect(media.mutedValues, [true]);
      expect(media.deafenedValues, [true]);
      expect(media.inputModes, [DiscordVoiceInputMode.pushToTalk]);
      expect(media.pushToTalkValues, [true]);
      expect(media.volumes, {'400000000000000004': 1.5});
      expect(mainGateway.voiceUpdates.last, (
        guildId: '100000000000000001',
        channelId: '200000000000000002',
        selfMute: true,
        selfDeaf: true,
      ));
      expect(coordinator.state.voice.selfMute, isTrue);
      expect(coordinator.state.voice.selfDeaf, isTrue);
    });

    test('leave는 Main Gateway 퇴장 후 media와 Voice Gateway를 정리한다', () async {
      await _connectReady(coordinator, network);

      await coordinator.leave();

      expect(mainGateway.voiceUpdates.last.channelId, isNull);
      expect(media.disposeCount, 1);
      expect(network.disposeCount, 1);
      expect(coordinator.state.voice.phase, DiscordVoicePhase.disconnecting);
      expect(
        coordinator.state.networkPhase,
        DiscordVoiceNetworkPhase.disconnected,
      );
    });

    test('새 Voice session 재협상 시 media engine을 교체한다', () async {
      await _connectReady(coordinator, network);
      await coordinator.setInputMode(DiscordVoiceInputMode.pushToTalk);
      final nextMedia = _FakeVoiceMediaConnection();
      replacementMedia = nextMedia;

      network.emit(
        DiscordVoiceNetworkState(phase: DiscordVoiceNetworkPhase.connecting),
      );
      await pumpEventQueue();
      network.emit(
        DiscordVoiceNetworkState(
          phase: DiscordVoiceNetworkPhase.ready,
          ssrc: 5252,
          encryptionMode: 'aead_aes256_gcm_rtpsize',
          secretKey: Uint8List(32),
          daveProtocolVersion: 1,
        ),
      );
      await pumpEventQueue();

      expect(media.disposeCount, 1);
      expect(nextMedia.startCount, 1);
      expect(nextMedia.inputModes, [DiscordVoiceInputMode.pushToTalk]);
      expect(coordinator.state.media.phase, DiscordVoiceMediaPhase.active);
      expect(coordinator.state.voice.phase, DiscordVoicePhase.ready);
    });

    test('복구 불가능한 Voice 실패 시 media engine을 정리한다', () async {
      await _connectReady(coordinator, network);

      network.emit(
        DiscordVoiceNetworkState(
          phase: DiscordVoiceNetworkPhase.failed,
          errorMessage: 'Voice 연결이 종료되었습니다.',
        ),
      );
      await pumpEventQueue();

      expect(media.disposeCount, 1);
      expect(coordinator.state.media.phase, DiscordVoiceMediaPhase.idle);
      expect(coordinator.state.voice.phase, DiscordVoicePhase.failed);
      expect(coordinator.state.errorMessage, contains('종료'));
    });

    test('카메라를 켜면 WebRTC video로 재협상하고 Gateway 상태를 갱신한다', () async {
      await _connectReady(coordinator, network);

      await coordinator.setCameraEnabled(true);

      expect(videoCapture.startCameraCount, 1);
      expect(
        network.connectedOptions?.videoSource,
        videoCapture.session.source,
      );
      expect(mainGateway.videoUpdates.single.selfVideo, isTrue);
      expect(coordinator.state.video.phase, DiscordVideoPhase.active);
    });

    test('카메라를 끄면 캡처를 정리하고 audio-only로 재협상한다', () async {
      await _connectReady(coordinator, network);
      await coordinator.setCameraEnabled(true);

      await coordinator.setCameraEnabled(false);

      expect(videoCapture.stopCount, 1);
      expect(network.connectedOptions?.usesWebRtc, isFalse);
      expect(mainGateway.videoUpdates.last.selfVideo, isFalse);
      expect(coordinator.state.video.phase, DiscordVideoPhase.idle);
    });

    test('원격 사용자 video preview를 UI 상태에 반영하고 제거한다', () async {
      await _connectReady(coordinator, network);
      final preview = Object();

      media.emit(
        media.state.copyWith(
          remoteVideoPreviews: {'400000000000000004': preview},
        ),
      );
      await pumpEventQueue();

      expect(
        coordinator.state.video.remotePreviews['400000000000000004'],
        same(preview),
      );

      media.emit(media.state.copyWith(remoteVideoPreviews: const {}));
      await pumpEventQueue();
      expect(coordinator.state.video.remotePreviews, isEmpty);
    });

    test('Go Live는 별도 Voice 연결로 화면을 송출하고 중지한다', () async {
      await _connectReady(coordinator, network);

      await coordinator.setScreenShareEnabled(true);
      expect(screenCapture.startScreenCount, 1);
      expect(mainGateway.createdStreams, [
        (guildId: '100000000000000001', channelId: '200000000000000002'),
      ]);

      coordinator.receiveGatewayEvent(
        _streamServerEvent(_selfStreamKey),
        currentUserId: '300000000000000003',
      );
      coordinator.receiveGatewayEvent(
        _streamCreateEvent(_selfStreamKey),
        currentUserId: '300000000000000003',
      );
      await pumpEventQueue();

      expect(streamNetwork.connectedCredentials?.guildId, '400000000000000004');
      expect(
        streamNetwork.connectedCredentials?.channelId,
        '500000000000000005',
      );
      expect(
        streamNetwork.connectedOptions?.videoSource,
        screenCapture.session.source,
      );
      expect(network.disposeCount, 0);

      streamNetwork.emit(
        DiscordVoiceNetworkState(
          phase: DiscordVoiceNetworkPhase.ready,
          ssrc: 700,
          videoSsrc: 701,
          rtxSsrc: 702,
        ),
      );
      await pumpEventQueue();
      expect(coordinator.state.video.screenShareEnabled, isTrue);

      await coordinator.setScreenSharePaused(true);
      expect(mainGateway.pausedStreams.single.paused, isTrue);

      await coordinator.setScreenShareEnabled(false);
      expect(mainGateway.deletedStreams, [_selfStreamKey]);
      expect(screenCapture.stopCount, 1);
      expect(streamNetwork.disposeCount, 1);
    });

    test('Go Live 시청은 receive-only 연결과 수신 media를 사용한다', () async {
      await _connectReady(coordinator, network);

      await coordinator.watchStream(_streamKey);
      expect(mainGateway.watchedStreams, [_streamKey]);
      coordinator.receiveGatewayEvent(
        _streamCreateEvent(),
        currentUserId: '300000000000000003',
      );
      coordinator.receiveGatewayEvent(
        _streamServerEvent(),
        currentUserId: '300000000000000003',
      );
      await pumpEventQueue();

      expect(streamNetwork.connectedOptions?.videoSource, isNull);
      expect(streamNetwork.connectedOptions?.usesWebRtc, isTrue);
      streamNetwork.emit(
        DiscordVoiceNetworkState(
          phase: DiscordVoiceNetworkPhase.ready,
          ssrc: 700,
          videoSsrc: 701,
          rtxSsrc: 702,
        ),
      );
      await pumpEventQueue();

      expect(streamMedia.startCount, 1);
      expect(coordinator.state.video.watchingStreamKey, _streamKey);
      final preview = Object();
      streamMedia.emit(
        streamMedia.state.copyWith(
          remoteVideoPreviews: {'600000000000000006': preview},
        ),
      );
      await pumpEventQueue();
      expect(
        coordinator.state.video.remotePreviews['600000000000000006'],
        same(preview),
      );
    });

    test('Voice 준비 전 제어와 잘못된 stream key를 경계에서 거부한다', () async {
      expect(await coordinator.states.first, const DiscordVoiceUiState());
      await coordinator.stopWatchingStream();

      final stateUpdates = StreamIterator(coordinator.states);
      expect(await stateUpdates.moveNext(), isTrue);
      final nextState = stateUpdates.moveNext();
      await pumpEventQueue();
      await coordinator.setInputMode(DiscordVoiceInputMode.pushToTalk);
      expect(await nextState, isTrue);
      expect(
        stateUpdates.current.media.inputMode,
        DiscordVoiceInputMode.pushToTalk,
      );
      await stateUpdates.cancel();
      expect(
        coordinator.state.media.inputMode,
        DiscordVoiceInputMode.pushToTalk,
      );
      await expectLater(coordinator.setMuted(true), throwsStateError);
      await expectLater(
        coordinator.setPushToTalkPressed(true),
        throwsStateError,
      );
      expect(
        () => coordinator.setUserVolume('400000000000000004', 1),
        throwsStateError,
      );
      await expectLater(coordinator.setCameraEnabled(true), throwsStateError);
      await expectLater(
        coordinator.setScreenShareEnabled(true),
        throwsStateError,
      );
      await expectLater(
        coordinator.setScreenSharePaused(true),
        throwsStateError,
      );
      await expectLater(
        coordinator.watchStream('invalid-stream-key'),
        throwsStateError,
      );

      await coordinator.reset();
      expect(coordinator.state, const DiscordVoiceUiState());
    });

    test('Go Live 시청을 명시적으로 중지하면 별도 연결을 정리한다', () async {
      await _connectReady(coordinator, network);
      await expectLater(
        coordinator.watchStream('invalid-stream-key'),
        throwsFormatException,
      );
      await coordinator.watchStream(_streamKey);

      await coordinator.stopWatchingStream();

      expect(mainGateway.deletedStreams, [_streamKey]);
      expect(coordinator.state.video.watchingStreamKey, isNull);
      expect(streamNetwork.disposeCount, 0);
    });

    test('예상하지 못한 STREAM_DELETE를 사용자 오류로 노출하고 정리한다', () async {
      await _connectReady(coordinator, network);
      await coordinator.watchStream(_streamKey);

      coordinator.receiveGatewayEvent(
        _streamDeleteEvent(reason: 'stream_full'),
        currentUserId: '300000000000000003',
      );
      await pumpEventQueue();

      expect(coordinator.state.video.watchingStreamKey, isNull);
      expect(coordinator.state.errorMessage, contains('stream_full'));
    });

    test('Go Live Voice 연결 실패를 UI 상태에 반영한다', () async {
      await _connectReady(coordinator, network);
      await coordinator.watchStream(_streamKey);
      coordinator.receiveGatewayEvent(
        _streamCreateEvent(),
        currentUserId: '300000000000000003',
      );
      coordinator.receiveGatewayEvent(
        _streamServerEvent(),
        currentUserId: '300000000000000003',
      );
      await pumpEventQueue();

      streamNetwork.emit(
        DiscordVoiceNetworkState(
          phase: DiscordVoiceNetworkPhase.failed,
          errorMessage: 'stream network failure',
        ),
      );
      await pumpEventQueue();

      expect(coordinator.state.errorMessage, 'stream network failure');
    });

    test('dispose 이후에는 새 Voice 작업을 시작하지 않는다', () async {
      await coordinator.dispose();

      await expectLater(
        coordinator.join(guildId: '100000000000000001', channelId: '2'),
        throwsStateError,
      );
    });
  });
}
