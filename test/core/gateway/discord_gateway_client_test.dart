import 'dart:async';
import 'dart:convert';

import 'package:discord_native/core/gateway/discord_gateway_client.dart';
import 'package:discord_native/core/gateway/gateway_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordGatewayClient', () {
    late _FakeGatewayTransport transport;
    late _FakeHeartbeatScheduler scheduler;
    late _FakeReconnectScheduler reconnectScheduler;
    late DiscordGatewayClient client;

    setUp(() {
      transport = _FakeGatewayTransport();
      scheduler = _FakeHeartbeatScheduler();
      reconnectScheduler = _FakeReconnectScheduler();
      client = DiscordGatewayClient(
        transport: transport,
        heartbeatScheduler: scheduler,
        reconnectScheduler: reconnectScheduler,
      );
    });

    tearDown(() async {
      await client.dispose();
      await transport.dispose();
    });

    test('v10 JSON Gateway에 연결하고 HELLO를 기다린다', () async {
      await client.connect('  abc.def.ghi  ');

      expect(
        transport.connectedUri,
        Uri.parse(
          'wss://gateway.discord.gg/?v=10&encoding=json&compress=zlib-stream',
        ),
      );
      expect(client.state.phase, GatewayPhase.awaitingHello);
    });

    test('HELLO 수신 시 IDENTIFY를 보내고 heartbeat를 예약한다', () async {
      await client.connect('abc.def.ghi');

      transport.addInbound(
        jsonEncode({
          'op': 10,
          'd': {'heartbeat_interval': 45000},
        }),
      );
      await pumpEventQueue();

      expect(transport.sentPayloads.single['op'], 2);
      expect(
        (transport.sentPayloads.single['d'] as Map<String, Object?>)['token'],
        'abc.def.ghi',
      );
      expect(
        (transport.sentPayloads.single['d']
            as Map<String, Object?>)['client_state'],
        {
          'guild_versions': <String, Object?>{},
          'highest_last_message_id': '0',
          'read_state_version': 0,
          'user_guild_settings_version': -1,
          'user_settings_version': -1,
          'private_channels_version': '0',
          'api_code_version': 0,
        },
      );
      expect(scheduler.interval, const Duration(seconds: 45));
      expect(client.state.phase, GatewayPhase.identifying);
    });

    test('heartbeat에는 최신 sequence를 싣고 ACK 상태를 추적한다', () async {
      await client.connect('abc.def.ghi');
      transport.addInbound(
        jsonEncode({
          'op': 10,
          'd': {'heartbeat_interval': 45000},
        }),
      );
      transport.addInbound(
        jsonEncode({'op': 0, 's': 77, 't': 'MESSAGE_CREATE', 'd': {}}),
      );
      await pumpEventQueue();

      await scheduler.tick();

      expect(transport.sentPayloads.last, {'op': 1, 'd': 77});
      expect(client.state.awaitingHeartbeatAck, isTrue);

      transport.addInbound(jsonEncode({'op': 11, 'd': null}));
      await pumpEventQueue();

      expect(client.state.awaitingHeartbeatAck, isFalse);
    });

    test('dispatch payload를 기능 계층에 그대로 전달한다', () async {
      await client.connect('abc.def.ghi');
      final event = client.events.first;

      transport.addInbound(
        jsonEncode({
          'op': 0,
          's': 1,
          't': 'GUILD_CREATE',
          'd': {'id': 'guild-1', 'name': 'General'},
        }),
      );

      expect(await event, containsPair('t', 'GUILD_CREATE'));
    });

    test('READY 이후 guild member·presence bulk subscription을 보낸다', () async {
      await client.connect('abc.def.ghi');
      transport.addInbound(
        jsonEncode({
          'op': 0,
          's': 1,
          't': 'READY',
          'd': {
            'session_id': 'session-1',
            'resume_gateway_url': 'wss://resume.discord.gg',
            'guilds': [
              {'id': 'guild-1'},
              {'id': 'guild-2'},
            ],
          },
        }),
      );
      await pumpEventQueue();

      expect(transport.sentPayloads.single, {
        'op': 37,
        'd': {
          'subscriptions': {
            'guild-1': {
              'typing': true,
              'threads': true,
              'activities': true,
              'member_updates': true,
              'thread_member_lists': [],
              'members': [],
              'channels': {},
            },
            'guild-2': {
              'typing': true,
              'threads': true,
              'activities': true,
              'member_updates': true,
              'thread_member_lists': [],
              'members': [],
              'channels': {},
            },
          },
        },
      });
    });

    test('음성 채널 참가와 퇴장에 OP4 Voice State Update를 보낸다', () async {
      await client.connect('abc.def.ghi');

      await client.updateVoiceState(
        guildId: 'guild-1',
        channelId: 'voice-1',
        selfMute: true,
        selfDeaf: false,
      );
      await client.updateVoiceState(
        guildId: 'guild-1',
        channelId: null,
        selfMute: false,
        selfDeaf: false,
      );

      expect(transport.sentPayloads, [
        {
          'op': 4,
          'd': {
            'guild_id': 'guild-1',
            'channel_id': 'voice-1',
            'self_mute': true,
            'self_deaf': false,
          },
        },
        {
          'op': 4,
          'd': {
            'guild_id': 'guild-1',
            'channel_id': null,
            'self_mute': false,
            'self_deaf': false,
          },
        },
      ]);
    });

    test('카메라 활성화 상태를 OP4 self_video로 알린다', () async {
      await client.connect('abc.def.ghi');

      await client.updateVoiceVideoState(
        guildId: 'guild-1',
        channelId: 'voice-1',
        selfMute: false,
        selfDeaf: false,
        selfVideo: true,
      );

      expect(transport.sentPayloads.single, {
        'op': 4,
        'd': {
          'guild_id': 'guild-1',
          'channel_id': 'voice-1',
          'self_mute': false,
          'self_deaf': false,
          'self_video': true,
        },
      });
    });

    test('Go Live 생성·일시정지·시청·종료 opcode를 보낸다', () async {
      await client.connect('abc.def.ghi');
      const streamKey = 'guild:guild-1:voice-1:user-1';

      await client.createStream(guildId: 'guild-1', channelId: 'voice-1');
      await client.setStreamPaused(streamKey: streamKey, paused: false);
      await client.watchStream(streamKey);
      await client.deleteStream(streamKey);

      expect(transport.sentPayloads, [
        {
          'op': 18,
          'd': {
            'type': 'guild',
            'guild_id': 'guild-1',
            'channel_id': 'voice-1',
            'preferred_region': null,
          },
        },
        {
          'op': 22,
          'd': {'stream_key': streamKey, 'paused': false},
        },
        {
          'op': 20,
          'd': {'stream_key': streamKey},
        },
        {
          'op': 19,
          'd': {'stream_key': streamKey},
        },
      ]);
    });

    test('빈 guild ID로 Voice State Update를 보내지 않는다', () async {
      await client.connect('abc.def.ghi');

      expect(
        () => client.updateVoiceState(
          guildId: '  ',
          channelId: 'voice-1',
          selfMute: false,
          selfDeaf: false,
        ),
        throwsFormatException,
      );
      expect(transport.sentPayloads, isEmpty);
    });

    test('OP7 이후 resume URL에 재접속하고 OP6 RESUME을 보낸다', () async {
      await client.connect('abc.def.ghi');
      transport.addInbound(
        jsonEncode({
          'op': 10,
          'd': {'heartbeat_interval': 45000},
        }),
      );
      transport.addInbound(
        jsonEncode({
          'op': 0,
          's': 42,
          't': 'READY',
          'd': {
            'session_id': 'session-1',
            'resume_gateway_url': 'wss://resume.discord.gg',
          },
        }),
      );
      await pumpEventQueue();

      transport.addInbound(jsonEncode({'op': 7, 'd': null}));
      await pumpEventQueue();
      expect(reconnectScheduler.delays, [Duration.zero]);

      await reconnectScheduler.runNext();
      transport.addInbound(
        jsonEncode({
          'op': 10,
          'd': {'heartbeat_interval': 45000},
        }),
      );
      await pumpEventQueue();

      expect(
        transport.connectedUris.last,
        Uri.parse(
          'wss://resume.discord.gg/'
          '?v=10&encoding=json&compress=zlib-stream',
        ),
      );
      expect(transport.sentPayloads.last['op'], 6);
      expect(
        transport.sentPayloads.last['d'],
        containsPair('session_id', 'session-1'),
      );
    });

    test('heartbeat ACK가 없으면 다음 tick에서 즉시 재연결한다', () async {
      await client.connect('abc.def.ghi');
      transport.addInbound(
        jsonEncode({
          'op': 10,
          'd': {'heartbeat_interval': 45000},
        }),
      );
      await pumpEventQueue();

      await scheduler.tick();
      await scheduler.tick();

      expect(reconnectScheduler.delays, [Duration.zero]);
      expect(
        transport.sentPayloads.where((payload) => payload['op'] == 1),
        hasLength(1),
      );
    });

    test('연속 transport 오류에 1초, 2초 지수 backoff를 적용한다', () async {
      await client.connect('abc.def.ghi');

      transport.addError(StateError('first'));
      await pumpEventQueue();
      expect(reconnectScheduler.delays, [const Duration(seconds: 1)]);

      await reconnectScheduler.runNext();
      transport.addError(StateError('second'));
      await pumpEventQueue();

      expect(reconnectScheduler.delays, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });

    test('dispose 시 heartbeat와 WebSocket을 정리한다', () async {
      await client.connect('abc.def.ghi');
      transport.addInbound(
        jsonEncode({
          'op': 10,
          'd': {'heartbeat_interval': 45000},
        }),
      );
      await pumpEventQueue();

      await client.dispose();

      expect(scheduler.task.isCancelled, isTrue);
      expect(transport.isClosed, isTrue);
    });
  });
}

final class _FakeGatewayTransport implements GatewayTransport {
  final StreamController<Object?> _inbound = StreamController.broadcast();

  Uri? connectedUri;
  List<Uri> connectedUris = const [];
  List<Map<String, Object?>> sentPayloads = const [];
  bool isClosed = false;

  @override
  Stream<Object?> get messages => _inbound.stream;

  void addInbound(Object? message) => _inbound.add(message);

  void addError(Object error) => _inbound.addError(error);

  @override
  Future<void> close() async {
    isClosed = true;
  }

  @override
  Future<void> connect(Uri uri) async {
    connectedUri = uri;
    connectedUris = List.unmodifiable([...connectedUris, uri]);
    isClosed = false;
  }

  Future<void> dispose() => _inbound.close();

  @override
  Future<void> send(Map<String, Object?> payload) async {
    sentPayloads = List.unmodifiable([...sentPayloads, payload]);
  }
}

final class _FakeReconnectScheduler implements GatewayReconnectScheduler {
  List<Duration> delays = const [];
  List<Future<void> Function()> _callbacks = const [];
  _FakeScheduledTask task = _FakeScheduledTask();

  @override
  GatewayScheduledTask schedule(
    Duration delay,
    Future<void> Function() callback,
  ) {
    delays = List.unmodifiable([...delays, delay]);
    _callbacks = List.unmodifiable([..._callbacks, callback]);
    task = _FakeScheduledTask();
    return task;
  }

  Future<void> runNext() async {
    final callback = _callbacks.first;
    _callbacks = List.unmodifiable(_callbacks.skip(1));
    await callback();
  }
}

final class _FakeHeartbeatScheduler implements GatewayHeartbeatScheduler {
  Duration? interval;
  Future<void> Function()? _callback;
  _FakeScheduledTask task = _FakeScheduledTask();

  @override
  GatewayScheduledTask schedule(
    Duration interval,
    Future<void> Function() callback,
  ) {
    this.interval = interval;
    _callback = callback;
    task = _FakeScheduledTask();
    return task;
  }

  Future<void> tick() async {
    final callback = _callback;
    if (callback != null) {
      await callback();
    }
  }
}

final class _FakeScheduledTask implements GatewayScheduledTask {
  bool isCancelled = false;

  @override
  void cancel() {
    isCancelled = true;
  }
}
