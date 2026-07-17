import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_dave_session.dart';
import 'package:discord_native/features/voice/data/discord_voice_gateway_client.dart';
import 'package:discord_native/features/voice/domain/discord_voice_state.dart';
import 'package:discord_native/features/video/domain/discord_video_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

part 'discord_voice_gateway_client_test_support.dart';

void main() {
  group('DiscordVoiceGatewayClient', () {
    late _FakeVoiceGatewayTransport transport;
    late _FakeVoiceUdpTransport udp;
    late _FakeVoiceHeartbeatScheduler scheduler;
    late _FakeDiscordDaveSession daveSession;
    late _FakeVoiceRtcTransport rtcTransport;
    late DiscordVoiceGatewayClient client;
    late List<Duration> reconnectDelays;

    const credentials = DiscordVoiceCredentials(
      guildId: '100000000000000001',
      channelId: '200000000000000002',
      userId: '300000000000000003',
      sessionId: 'session-1',
      token: 'voice-token',
      endpoint: 'rotterdam123.discord.media',
    );

    setUp(() {
      transport = _FakeVoiceGatewayTransport();
      udp = _FakeVoiceUdpTransport();
      scheduler = _FakeVoiceHeartbeatScheduler();
      daveSession = _FakeDiscordDaveSession();
      rtcTransport = _FakeVoiceRtcTransport();
      reconnectDelays = const [];
      client = DiscordVoiceGatewayClient(
        transport: transport,
        udp: udp,
        daveSession: daveSession,
        rtcTransport: rtcTransport,
        heartbeatScheduler: scheduler,
        maxDaveProtocolVersion: 1,
        nowMilliseconds: () => 123456789,
        reconnectDelay: (delay) async {
          reconnectDelays = List.unmodifiable([...reconnectDelays, delay]);
        },
      );
    });

    tearDown(() async {
      await client.dispose();
      await rtcTransport.dispose();
      await transport.dispose();
    });

    test('Voice v8 endpoint에 연결하고 DAVE 지원 Identify를 보낸다', () async {
      await client.connect(credentials);

      expect(
        transport.connectedUri,
        Uri.parse('wss://rotterdam123.discord.media?v=8'),
      );
      expect(transport.sentJson.single, {
        'op': 0,
        'd': {
          'server_id': '100000000000000001',
          'user_id': '300000000000000003',
          'session_id': 'session-1',
          'token': 'voice-token',
          'max_dave_protocol_version': 1,
        },
      });
      expect(client.state.phase, DiscordVoiceNetworkPhase.identifying);
    });

    test('Hello 간격으로 seq_ack heartbeat를 보내고 ACK를 추적한다', () async {
      await client.connect(credentials);
      transport.addJson({
        'op': 8,
        'seq': 7,
        'd': {'heartbeat_interval': 15000},
      });
      await pumpEventQueue();

      expect(scheduler.interval, const Duration(seconds: 15));
      await scheduler.tick();

      expect(transport.sentJson.last, {
        'op': 3,
        'd': {'t': 123456789, 'seq_ack': 7},
      });
      expect(client.state.awaitingHeartbeatAck, isTrue);

      transport.addJson({
        'op': 6,
        'd': {'t': 123456789},
      });
      await pumpEventQueue();

      expect(client.state.awaitingHeartbeatAck, isFalse);
    });

    test('heartbeat ACK가 누락되면 Voice v8 session을 즉시 resume한다', () async {
      await _prepareReadyClient(client, transport);
      transport.addJson({
        'op': 8,
        'seq': 12,
        'd': {'heartbeat_interval': 15000},
      });
      await pumpEventQueue();

      await scheduler.tick();
      await scheduler.tick();
      await pumpEventQueue();

      expect(transport.connectedUris, hasLength(2));
      expect(transport.sentJson.last, {
        'op': 7,
        'd': {
          'server_id': '100000000000000001',
          'session_id': 'session-1',
          'token': 'voice-token',
          'seq_ack': 12,
        },
      });
      expect(client.state.phase, DiscordVoiceNetworkPhase.resuming);
    });

    test('Ready 뒤 UDP IP discovery와 선호 AEAD protocol을 선택한다', () async {
      udp.discoveryResult = const VoiceIpDiscoveryResult(
        address: '203.0.113.7',
        port: 54321,
      );
      await client.connect(credentials);

      transport.addJson({
        'op': 2,
        'seq': 8,
        'd': {
          'ssrc': 4242,
          'ip': '198.51.100.10',
          'port': 50000,
          'modes': [
            'aead_xchacha20_poly1305_rtpsize',
            'aead_aes256_gcm_rtpsize',
          ],
        },
      });
      await pumpEventQueue();

      expect(udp.serverAddress, '198.51.100.10');
      expect(udp.serverPort, 50000);
      expect(udp.ssrc, 4242);
      expect(transport.sentJson.last, {
        'op': 1,
        'd': {
          'protocol': 'udp',
          'data': {
            'address': '203.0.113.7',
            'port': 54321,
            'mode': 'aead_aes256_gcm_rtpsize',
          },
        },
      });
      expect(client.state.phase, DiscordVoiceNetworkPhase.selectingProtocol);
      expect(client.state.ssrc, 4242);
    });

    test('AES가 없으면 필수 XChaCha20 Poly1305를 선택한다', () async {
      await client.connect(credentials);
      transport.addJson({
        'op': 2,
        'd': {
          'ssrc': 10,
          'ip': '198.51.100.10',
          'port': 50000,
          'modes': ['aead_xchacha20_poly1305_rtpsize'],
        },
      });
      await pumpEventQueue();

      expect(
        ((transport.sentJson.last['d'] as Map)['data'] as Map)['mode'],
        'aead_xchacha20_poly1305_rtpsize',
      );
    });

    test('카메라 연결은 video Identify와 WebRTC protocol을 협상한다', () async {
      const source = DiscordVideoSource.camera(
        sourceId: 'camera-1',
        width: 1280,
        height: 720,
        framesPerSecond: 30,
      );
      rtcTransport.offer = const DiscordVoiceRtcOffer(
        sdp: 'local-sdp',
        rtcConnectionId: 'rtc-connection-1',
      );

      await client.connect(
        credentials,
        options: const DiscordVoiceConnectionOptions.video(source),
      );

      expect(transport.sentJson.single, {
        'op': 0,
        'd': {
          'server_id': '100000000000000001',
          'user_id': '300000000000000003',
          'session_id': 'session-1',
          'token': 'voice-token',
          'video': true,
          'streams': [
            {'type': 'screen', 'rid': '100', 'quality': 100},
          ],
          'max_dave_protocol_version': 1,
        },
      });

      transport.addJson({
        'op': 2,
        'd': {
          'ssrc': 10,
          'ip': '198.51.100.10',
          'port': 50000,
          'modes': ['aead_aes256_gcm_rtpsize'],
          'streams': [
            {
              'type': 'video',
              'rid': '100',
              'ssrc': 11,
              'rtx_ssrc': 12,
              'active': false,
              'quality': 100,
            },
          ],
        },
      });
      await pumpEventQueue();

      expect(
        rtcTransport.session,
        const DiscordVoiceRtcSession(
          audioSsrc: 10,
          videoSsrc: 11,
          rtxSsrc: 12,
          source: source,
        ),
      );
      expect(transport.sentJson.last, {
        'op': 1,
        'd': {
          'protocol': 'webrtc',
          'codecs': DiscordVideoCodecCapabilities.gatewayPayload,
          'data': 'local-sdp',
          'sdp': 'local-sdp',
          'rtc_connection_id': 'rtc-connection-1',
        },
      });

      transport.addJson({
        'op': 4,
        'seq': 9,
        'd': {
          'audio_codec': 'opus',
          'video_codec': 'H264',
          'dave_protocol_version': 1,
          'media_session_id': 77,
          'sdp': 'remote-sdp',
        },
      });
      await pumpEventQueue();

      expect(client.state.phase, DiscordVoiceNetworkPhase.ready);
      expect(client.state.videoSsrc, 11);
      expect(client.state.rtxSsrc, 12);
      expect(client.state.videoCodec, DiscordVideoCodec.h264);
      expect(daveSession.localVideo, (
        ssrc: 11,
        codec: DiscordDaveVideoCodec.h264,
      ));
      expect(rtcTransport.answer?.sdp, 'remote-sdp');
      expect(rtcTransport.answer?.videoCodec, DiscordVideoCodec.h264);
      expect(rtcTransport.answer?.daveSession, same(daveSession));

      final receivedAudio = client.rtcAudioFrames.first;
      rtcTransport.emitAudio(
        DiscordVoiceRtcAudioFrame(
          ssrc: 5150,
          sequence: 7,
          encryptedOpus: Uint8List.fromList([0xDA, 0x31]),
        ),
      );
      await client.sendRtcAudio(Uint8List.fromList([0x11, 0x22]));

      expect((await receivedAudio).encryptedOpus, [0xDA, 0x31]);
      expect(rtcTransport.sentAudioFrames, [
        [0x11, 0x22],
      ]);
      expect(rtcTransport.sentAudioDurations, [20]);

      transport.addJson({
        'op': 12,
        'd': {
          'user_id': '400000000000000004',
          'audio_ssrc': 20,
          'video_ssrc': 21,
          'streams': [
            {'ssrc': 21, 'rtx_ssrc': 22, 'active': true},
          ],
        },
      });
      await pumpEventQueue();

      expect(client.state.videoUsersBySsrc, {21: '400000000000000004'});

      await client.setVideoEnabled(true);

      expect(transport.sentJson.last, {
        'op': 12,
        'd': {
          'audio_ssrc': 10,
          'video_ssrc': 11,
          'rtx_ssrc': 12,
          'streams': [
            {
              'type': 'video',
              'rid': '100',
              'ssrc': 11,
              'active': true,
              'quality': 100,
              'rtx_ssrc': 12,
              'max_bitrate': 10000000,
              'max_framerate': 30,
              'max_resolution': {'type': 'fixed', 'width': 1280, 'height': 720},
            },
          ],
        },
      });
    });

    test('Go Live 시청 연결은 local source 없이 WebRTC video를 협상한다', () async {
      rtcTransport.offer = const DiscordVoiceRtcOffer(
        sdp: 'local-sdp',
        rtcConnectionId: 'rtc-connection-1',
      );

      await client.connect(
        credentials,
        options: const DiscordVoiceConnectionOptions.receiveVideo(),
      );
      transport.addJson({
        'op': 2,
        'd': {
          'ssrc': 10,
          'ip': '198.51.100.10',
          'port': 50000,
          'modes': ['aead_aes256_gcm_rtpsize'],
          'streams': [
            {
              'type': 'video',
              'rid': '100',
              'ssrc': 11,
              'rtx_ssrc': 12,
              'active': false,
              'quality': 100,
            },
          ],
        },
      });
      await pumpEventQueue();

      expect(transport.sentJson.first['d'], containsPair('video', true));
      expect(
        rtcTransport.session,
        const DiscordVoiceRtcSession(audioSsrc: 10, videoSsrc: 11, rtxSsrc: 12),
      );
      expect(() => client.setVideoEnabled(true), throwsA(isA<StateError>()));
    });

    test('네이티브 WebRTC encoder 오류를 Voice 실패 상태로 전달한다', () async {
      rtcTransport.emitError('H264 encoder failed');
      await pumpEventQueue();

      expect(client.state.phase, DiscordVoiceNetworkPhase.failed);
      expect(client.state.errorMessage, contains('H264 encoder'));
    });

    test('Session Description의 32바이트 키와 DAVE 버전을 보존한다', () async {
      await client.connect(credentials);
      transport.addJson({
        'op': 2,
        'd': {
          'ssrc': 10,
          'ip': '198.51.100.10',
          'port': 50000,
          'modes': ['aead_xchacha20_poly1305_rtpsize'],
        },
      });
      await pumpEventQueue();
      transport.addJson({
        'op': 4,
        'seq': 9,
        'd': {
          'mode': 'aead_xchacha20_poly1305_rtpsize',
          'secret_key': List<int>.generate(32, (index) => index),
          'dave_protocol_version': 1,
        },
      });
      await pumpEventQueue();

      expect(client.state.phase, DiscordVoiceNetworkPhase.ready);
      expect(
        client.state.secretKey,
        Uint8List.fromList(List.generate(32, (i) => i)),
      );
      expect(client.state.daveProtocolVersion, 1);
      expect(client.state.encryptionMode, 'aead_xchacha20_poly1305_rtpsize');
      expect(daveSession.initialization, (
        protocolVersion: 1,
        groupId: 200000000000000002,
        selfUserId: '300000000000000003',
      ));
      expect(daveSession.localAudioSsrc, 10);
      expect(transport.sentBinary.single, [26, 7, 8, 9]);
    });

    test('서버 binary DAVE frame의 sequence와 opcode를 분리한다', () async {
      await client.connect(credentials);
      final nextBinary = client.binaryMessages.first;

      transport.addBinary(Uint8List.fromList([0x01, 0x02, 25, 9, 8, 7]));

      expect(
        await nextBinary,
        const VoiceGatewayBinaryMessage(
          sequence: 258,
          opcode: 25,
          payload: [9, 8, 7],
        ),
      );
      expect(client.state.sequence, 258);
    });

    test('Speaking과 Client Disconnect로 원격 사용자 SSRC를 추적한다', () async {
      await _prepareReadyClient(client, transport);

      transport.addJson({
        'op': 5,
        'd': {
          'speaking': 1,
          'delay': 0,
          'ssrc': 5150,
          'user_id': '400000000000000004',
        },
      });
      await pumpEventQueue();

      expect(client.state.usersBySsrc, {5150: '400000000000000004'});
      expect(
        () => client.state.usersBySsrc[5150] = '500000000000000005',
        throwsUnsupportedError,
      );

      transport.addJson({
        'op': 13,
        'd': {'user_id': '400000000000000004'},
      });
      await pumpEventQueue();

      expect(client.state.usersBySsrc, isEmpty);
    });

    test('준비된 미디어 frame을 DAVE로 보호하고 해제한다', () async {
      await _prepareReadyClient(client, transport);

      final protected = client.protectAudio(Uint8List.fromList([1, 2, 3]));
      final clear = client.unprotectAudio(
        Uint8List.fromList([4, 5, 6]),
        remoteUserId: '400000000000000004',
      );

      expect(protected, [1, 2, 3]);
      expect(clear, [4, 5, 6]);
      expect(daveSession.encryptedSsrc, 10);
      expect(daveSession.decryptedRemoteUserId, '400000000000000004');
    });

    test('일시적인 Voice Gateway 종료 뒤 OP7로 session을 resume한다', () async {
      await _prepareReadyClient(client, transport);
      final secretKey = Uint8List.fromList(client.state.secretKey!);

      transport.addClose(4015);
      await pumpEventQueue();

      expect(transport.connectedUris, hasLength(2));
      expect(transport.sentJson.last, {
        'op': 7,
        'd': {
          'server_id': '100000000000000001',
          'session_id': 'session-1',
          'token': 'voice-token',
          'seq_ack': 9,
        },
      });
      expect(client.state.phase, DiscordVoiceNetworkPhase.resuming);
      expect(
        () => client.protectAudio(Uint8List.fromList([1, 2, 3])),
        returnsNormally,
      );
      await client.sendUdp(Uint8List.fromList([4, 5, 6]));

      transport.addJson({'op': 9, 'd': null});
      await pumpEventQueue();

      expect(client.state.phase, DiscordVoiceNetworkPhase.ready);
      expect(client.state.secretKey, secretKey);
      expect(daveSession.initializationCount, 1);
    });

    test('Voice WebSocket 재접속 실패에 지수 backoff 후 재시도한다', () async {
      await _prepareReadyClient(client, transport);
      transport.connectFailuresRemaining = 1;

      transport.addClose(4015);
      await pumpEventQueue();

      expect(reconnectDelays, [const Duration(seconds: 1)]);
      expect(transport.connectAttempts, 3);
      expect(transport.sentJson.last['op'], 7);
      expect(client.state.phase, DiscordVoiceNetworkPhase.resuming);
    });

    test('resume session이 만료되면 새 Voice Identify로 재협상한다', () async {
      await _prepareReadyClient(client, transport);

      transport.addClose(4015);
      await pumpEventQueue();
      transport.addClose(4006);
      await pumpEventQueue();

      expect(transport.connectedUris, hasLength(3));
      expect(transport.sentJson.last, {
        'op': 0,
        'd': {
          'server_id': '100000000000000001',
          'user_id': '300000000000000003',
          'session_id': 'session-1',
          'token': 'voice-token',
          'max_dave_protocol_version': 1,
        },
      });
      expect(client.state.phase, DiscordVoiceNetworkPhase.identifying);
      expect(client.state.secretKey, isNull);
      expect(udp.closeCount, greaterThanOrEqualTo(2));
    });

    test('명시적인 연결 종료 close code는 재접속하지 않는다', () async {
      await _prepareReadyClient(client, transport);

      transport.addClose(4014);
      await pumpEventQueue();

      expect(transport.connectedUris, hasLength(1));
      expect(client.state.phase, DiscordVoiceNetworkPhase.failed);
      expect(client.state.errorMessage, contains('4014'));
    });

    test('client binary DAVE frame은 opcode 한 바이트를 앞에 붙인다', () async {
      await client.connect(credentials);

      await client.sendBinary(26, Uint8List.fromList([1, 2, 3]));

      expect(transport.sentBinary.single, Uint8List.fromList([26, 1, 2, 3]));
    });

    test('지원 AEAD가 없으면 실패 상태와 사용자 친화적 오류를 낸다', () async {
      await client.connect(credentials);
      transport.addJson({
        'op': 2,
        'd': {
          'ssrc': 10,
          'ip': '198.51.100.10',
          'port': 50000,
          'modes': ['xsalsa20_poly1305'],
        },
      });
      await pumpEventQueue();

      expect(client.state.phase, DiscordVoiceNetworkPhase.failed);
      expect(client.state.errorMessage, contains('호환되는 AEAD'));
    });
  });
}
