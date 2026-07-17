import 'dart:async';
import 'dart:convert';

import 'package:discord_native/core/auth/token_validator.dart';
import 'package:discord_native/core/gateway/gateway_reconnect_policy.dart';
import 'package:discord_native/core/gateway/gateway_session_state.dart';
import 'package:discord_native/core/gateway/gateway_zlib_stream_decoder.dart';

abstract interface class GatewayTransport {
  Stream<Object?> get messages;

  Future<void> connect(Uri uri);

  Future<void> send(Map<String, Object?> payload);

  Future<void> close();
}

abstract interface class GatewayScheduledTask {
  void cancel();
}

abstract interface class GatewayHeartbeatScheduler {
  GatewayScheduledTask schedule(
    Duration interval,
    Future<void> Function() callback,
  );
}

abstract interface class GatewayReconnectScheduler {
  GatewayScheduledTask schedule(
    Duration delay,
    Future<void> Function() callback,
  );
}

abstract interface class DiscordGatewayConnection {
  GatewaySessionState get state;

  Stream<GatewaySessionState> get states;

  Stream<Map<String, Object?>> get events;

  Future<void> connect(String input);

  Future<void> updateVoiceState({
    required String guildId,
    required String? channelId,
    required bool selfMute,
    required bool selfDeaf,
  });

  Future<void> disconnect();

  Future<void> dispose();
}

abstract interface class DiscordVideoGatewayConnection {
  Future<void> updateVoiceVideoState({
    required String guildId,
    required String channelId,
    required bool selfMute,
    required bool selfDeaf,
    required bool selfVideo,
  });

  Future<void> createStream({
    required String guildId,
    required String channelId,
  });

  Future<void> setStreamPaused({
    required String streamKey,
    required bool paused,
  });

  Future<void> watchStream(String streamKey);

  Future<void> deleteStream(String streamKey);
}

final class TimerGatewayHeartbeatScheduler
    implements GatewayHeartbeatScheduler {
  const TimerGatewayHeartbeatScheduler();

  @override
  GatewayScheduledTask schedule(
    Duration interval,
    Future<void> Function() callback,
  ) {
    final timer = Timer.periodic(interval, (_) => unawaited(callback()));
    return _TimerScheduledTask(timer);
  }
}

final class TimerGatewayReconnectScheduler
    implements GatewayReconnectScheduler {
  const TimerGatewayReconnectScheduler();

  @override
  GatewayScheduledTask schedule(
    Duration delay,
    Future<void> Function() callback,
  ) {
    final timer = Timer(delay, () => unawaited(callback()));
    return _TimerScheduledTask(timer);
  }
}

final class _TimerScheduledTask implements GatewayScheduledTask {
  const _TimerScheduledTask(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

final class DiscordGatewayClient
    implements DiscordGatewayConnection, DiscordVideoGatewayConnection {
  DiscordGatewayClient({
    required GatewayTransport transport,
    GatewayHeartbeatScheduler heartbeatScheduler =
        const TimerGatewayHeartbeatScheduler(),
    GatewayReconnectScheduler reconnectScheduler =
        const TimerGatewayReconnectScheduler(),
    GatewayBackoffPolicy backoffPolicy = const GatewayBackoffPolicy(),
    GatewayMessageDecoder? messageDecoder,
  }) : _transport = transport,
       _heartbeatScheduler = heartbeatScheduler,
       _reconnectScheduler = reconnectScheduler,
       _backoffPolicy = backoffPolicy,
       _messageDecoder = messageDecoder ?? GatewayZlibStreamDecoder();

  static final Uri gatewayUri = Uri.parse(
    'wss://gateway.discord.gg/'
    '?v=10&encoding=json&compress=zlib-stream',
  );

  final GatewayTransport _transport;
  final GatewayHeartbeatScheduler _heartbeatScheduler;
  final GatewayReconnectScheduler _reconnectScheduler;
  final GatewayBackoffPolicy _backoffPolicy;
  final GatewayMessageDecoder _messageDecoder;
  final StreamController<GatewaySessionState> _states =
      StreamController.broadcast();
  final StreamController<Map<String, Object?>> _events =
      StreamController.broadcast();

  GatewaySessionState _state = const GatewaySessionState.disconnected();
  StreamSubscription<Object?>? _subscription;
  GatewayScheduledTask? _heartbeatTask;
  GatewayScheduledTask? _reconnectTask;
  String? _token;
  int _reconnectAttempt = 0;
  bool _disposed = false;

  @override
  GatewaySessionState get state => _state;

  @override
  Stream<GatewaySessionState> get states => _states.stream;

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Future<void> connect(String input) async {
    _ensureActive();
    if (_subscription != null) {
      await disconnect();
    }
    final token = TokenValidator.validate(input);
    _token = token;
    _reconnectAttempt = 0;
    _messageDecoder.reset();
    await _open(gatewayUri);
  }

  @override
  Future<void> updateVoiceState({
    required String guildId,
    required String? channelId,
    required bool selfMute,
    required bool selfDeaf,
  }) async {
    _ensureActive();
    if (_token == null) {
      throw StateError('Gateway가 연결되지 않았습니다.');
    }
    final normalizedGuildId = guildId.trim();
    if (normalizedGuildId.isEmpty) {
      throw const FormatException('음성 상태의 guild ID가 필요합니다.');
    }
    final normalizedChannelId = channelId?.trim();
    if (normalizedChannelId != null && normalizedChannelId.isEmpty) {
      throw const FormatException('음성 상태의 channel ID 형식이 올바르지 않습니다.');
    }
    await _transport.send({
      'op': 4,
      'd': {
        'guild_id': normalizedGuildId,
        'channel_id': normalizedChannelId,
        'self_mute': selfMute,
        'self_deaf': selfDeaf,
      },
    });
  }

  @override
  Future<void> updateVoiceVideoState({
    required String guildId,
    required String channelId,
    required bool selfMute,
    required bool selfDeaf,
    required bool selfVideo,
  }) async {
    final normalizedGuildId = _requiredGatewayValue(guildId, 'guild ID');
    final normalizedChannelId = _requiredGatewayValue(channelId, 'channel ID');
    await _sendAuthenticated({
      'op': 4,
      'd': {
        'guild_id': normalizedGuildId,
        'channel_id': normalizedChannelId,
        'self_mute': selfMute,
        'self_deaf': selfDeaf,
        'self_video': selfVideo,
      },
    });
  }

  @override
  Future<void> createStream({
    required String guildId,
    required String channelId,
  }) async {
    await _sendAuthenticated({
      'op': 18,
      'd': {
        'type': 'guild',
        'guild_id': _requiredGatewayValue(guildId, 'stream guild ID'),
        'channel_id': _requiredGatewayValue(channelId, 'stream channel ID'),
        'preferred_region': null,
      },
    });
  }

  @override
  Future<void> setStreamPaused({
    required String streamKey,
    required bool paused,
  }) async {
    await _sendStreamCommand(22, streamKey, extra: {'paused': paused});
  }

  @override
  Future<void> watchStream(String streamKey) async {
    await _sendStreamCommand(20, streamKey);
  }

  @override
  Future<void> deleteStream(String streamKey) async {
    await _sendStreamCommand(19, streamKey);
  }

  Future<void> _sendStreamCommand(
    int opcode,
    String streamKey, {
    Map<String, Object?> extra = const {},
  }) async {
    await _sendAuthenticated({
      'op': opcode,
      'd': {
        'stream_key': _requiredGatewayValue(streamKey, 'stream key'),
        ...extra,
      },
    });
  }

  Future<void> _sendAuthenticated(Map<String, Object?> payload) async {
    _ensureActive();
    if (_token == null) {
      throw StateError('Gateway가 연결되지 않았습니다.');
    }
    await _transport.send(payload);
  }

  @override
  Future<void> disconnect() async {
    _ensureActive();
    _heartbeatTask?.cancel();
    _heartbeatTask = null;
    _reconnectTask?.cancel();
    _reconnectTask = null;
    await _subscription?.cancel();
    _subscription = null;
    _token = null;
    _reconnectAttempt = 0;
    await _transport.close();
    _update(const GatewaySessionState.disconnected());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _heartbeatTask?.cancel();
    _heartbeatTask = null;
    _reconnectTask?.cancel();
    _reconnectTask = null;
    await _subscription?.cancel();
    _subscription = null;
    _token = null;
    await _transport.close();
    await _states.close();
    await _events.close();
  }

  Future<void> _receive(Object? message) async {
    try {
      final decodedMessage = _messageDecoder.decode(message);
      if (decodedMessage == null) {
        return;
      }
      final payload = _decodePayload(decodedMessage);
      _update(_state.payloadReceived(payload));
      if (payload['op'] == 0 && !_events.isClosed) {
        _events.add(Map.unmodifiable(payload));
      }
      if (payload['op'] == 0 && payload['t'] == 'READY') {
        await _subscribeGuilds(payload['d']);
      }
      if (payload['op'] == 0 &&
          (payload['t'] == 'READY' || payload['t'] == 'RESUMED')) {
        _reconnectAttempt = 0;
      }
      switch (payload['op']) {
        case 10:
          if (_state.phase == GatewayPhase.resuming) {
            await _resume();
          } else {
            await _identify();
          }
          _startHeartbeat();
        case 1:
          await _sendHeartbeat(ignoreMissingAck: true);
        case 7:
          await _scheduleReconnect(immediate: true);
        case 9:
          await _scheduleReconnect(immediate: payload['d'] == true);
      }
    } on Object catch (error, stackTrace) {
      _handleTransportError(error, stackTrace);
    }
  }

  Future<void> _identify() async {
    final token = _token;
    if (token == null) {
      throw StateError('Gateway 연결 토큰이 없습니다.');
    }
    await _transport.send({
      'op': 2,
      'd': {
        'token': token,
        'capabilities': 30717,
        'properties': {
          'os': 'Windows',
          'browser': 'Discord Native',
          'device': 'Discord Native',
          'system_locale': 'ko-KR',
          'release_channel': 'stable',
        },
        'compress': false,
      },
    });
  }

  Future<void> _subscribeGuilds(Object? rawData) async {
    if (rawData is! Map || rawData['guilds'] is! List) {
      return;
    }
    final guildIds = <String>[
      for (final rawGuild in rawData['guilds'] as List)
        if (rawGuild is Map && rawGuild['id'] is String)
          rawGuild['id'] as String,
    ];
    for (var offset = 0; offset < guildIds.length; offset += 80) {
      final batch = guildIds.skip(offset).take(80);
      await _transport.send({
        'op': 37,
        'd': {
          'subscriptions': {
            for (final guildId in batch)
              guildId: {
                'typing': true,
                'threads': true,
                'activities': true,
                'member_updates': true,
                'thread_member_lists': const [],
                'members': const [],
                'channels': const <String, Object?>{},
              },
          },
        },
      });
    }
  }

  Future<void> _resume() async {
    final token = _token;
    final sessionId = _state.sessionId;
    final sequence = _state.sequence;
    if (token == null || sessionId == null || sequence == null) {
      throw StateError('Gateway RESUME 세션 정보가 없습니다.');
    }
    await _transport.send({
      'op': 6,
      'd': {'token': token, 'session_id': sessionId, 'seq': sequence},
    });
  }

  void _startHeartbeat() {
    final interval = _state.heartbeatInterval;
    if (interval == null) {
      throw StateError('Gateway heartbeat 간격이 없습니다.');
    }
    _heartbeatTask?.cancel();
    _heartbeatTask = _heartbeatScheduler.schedule(interval, _sendHeartbeat);
  }

  Future<void> _sendHeartbeat({bool ignoreMissingAck = false}) async {
    if (_state.awaitingHeartbeatAck && !ignoreMissingAck) {
      await _scheduleReconnect(immediate: true);
      return;
    }
    _update(_state.heartbeatSent());
    await _transport.send({'op': 1, 'd': _state.sequence});
  }

  void _handleTransportError(Object error, StackTrace stackTrace) {
    unawaited(_scheduleReconnect(immediate: false));
  }

  void _handleTransportDone() {
    if (!_disposed) {
      unawaited(_scheduleReconnect(immediate: false));
    }
  }

  Future<void> _scheduleReconnect({required bool immediate}) async {
    if (_disposed || _token == null || _reconnectTask != null) {
      return;
    }
    _heartbeatTask?.cancel();
    _heartbeatTask = null;
    _update(_state.copyWith(phase: GatewayPhase.reconnecting));
    final delay = immediate
        ? Duration.zero
        : _backoffPolicy.delayForAttempt(_reconnectAttempt++);
    _reconnectTask = _reconnectScheduler.schedule(delay, () async {
      _reconnectTask = null;
      await _reconnect();
    });
  }

  Future<void> _reconnect() async {
    if (_disposed || _token == null) {
      return;
    }
    await _subscription?.cancel();
    _subscription = null;
    await _transport.close();
    _messageDecoder.reset();
    await _open(_resumeUri());
  }

  Future<void> _open(Uri uri) async {
    await _transport.connect(uri);
    _update(_state.connectionOpened());
    _subscription = _transport.messages.listen(
      (message) => unawaited(_receive(message)),
      onError: _handleTransportError,
      onDone: _handleTransportDone,
    );
  }

  Uri _resumeUri() {
    final resumeUrl = _state.resumeGatewayUrl;
    if (resumeUrl == null) {
      return gatewayUri;
    }
    final uri = Uri.parse(resumeUrl);
    return uri.replace(
      path: uri.path.isEmpty ? '/' : uri.path,
      queryParameters: const {
        'v': '10',
        'encoding': 'json',
        'compress': 'zlib-stream',
      },
    );
  }

  void _update(GatewaySessionState nextState) {
    _state = nextState;
    if (!_states.isClosed) {
      _states.add(nextState);
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('이미 종료된 Gateway client입니다.');
    }
  }
}

Map<String, Object?> _decodePayload(Object? message) {
  final decoded = switch (message) {
    final String text => jsonDecode(text),
    final Map<Object?, Object?> map => map,
    _ => throw const FormatException('Gateway payload 형식이 올바르지 않습니다.'),
  };
  if (decoded is! Map) {
    throw const FormatException('Gateway payload는 JSON object여야 합니다.');
  }
  return decoded.map((key, value) => MapEntry(key.toString(), value));
}

String _requiredGatewayValue(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw FormatException('$field 값이 필요합니다.');
  }
  return normalized;
}
