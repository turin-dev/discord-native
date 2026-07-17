import 'package:discord_native/features/voice/domain/discord_voice_state.dart';

final class DiscordStreamState {
  const DiscordStreamState({
    required this.requestedStreamKey,
    this.rtcServerId,
    this.rtcChannelId,
    this.token,
    this.endpoint,
    this.paused = false,
    this.deleteReason,
  });

  final String requestedStreamKey;
  final String? rtcServerId;
  final String? rtcChannelId;
  final String? token;
  final String? endpoint;
  final bool paused;
  final String? deleteReason;

  DiscordVoiceCredentials? credentials({
    required String userId,
    required String sessionId,
  }) {
    final serverId = rtcServerId;
    final channelId = rtcChannelId;
    final activeToken = token;
    final activeEndpoint = endpoint;
    if (serverId == null ||
        channelId == null ||
        activeToken == null ||
        activeEndpoint == null) {
      return null;
    }
    return DiscordVoiceCredentials(
      guildId: serverId,
      channelId: channelId,
      userId: _requiredId(userId, 'stream user ID'),
      sessionId: _requiredValue(sessionId, 'stream session ID'),
      token: activeToken,
      endpoint: activeEndpoint,
    );
  }

  DiscordStreamState receiveGatewayEvent(Map<String, Object?> event) {
    if (event['op'] != 0) {
      return this;
    }
    final data = _eventData(event['d']);
    final streamKey = data['stream_key'];
    if (streamKey is! String || streamKey != requestedStreamKey) {
      return this;
    }
    return switch (event['t']) {
      'STREAM_CREATE' => _receiveCreate(data),
      'STREAM_SERVER_UPDATE' => _receiveServer(data),
      'STREAM_UPDATE' => _receiveUpdate(data),
      'STREAM_DELETE' => _receiveDelete(data),
      _ => this,
    };
  }

  DiscordStreamState _receiveCreate(Map<String, Object?> data) {
    return _copyWith(
      rtcServerId: _requiredId(data['rtc_server_id'], 'stream RTC server ID'),
      rtcChannelId: _requiredId(
        data['rtc_channel_id'],
        'stream RTC channel ID',
      ),
      paused: _requiredBool(data['paused'], 'stream paused'),
      deleteReason: null,
    );
  }

  DiscordStreamState _receiveServer(Map<String, Object?> data) {
    final endpoint = switch (data['endpoint']) {
      null => null,
      final String value => _normalizeEndpoint(value),
      _ => throw const FormatException('stream endpoint 형식이 올바르지 않습니다.'),
    };
    return _copyWith(
      token: _requiredValue(data['token'], 'stream token'),
      endpoint: endpoint,
      deleteReason: null,
    );
  }

  DiscordStreamState _receiveUpdate(Map<String, Object?> data) {
    return _copyWith(paused: _requiredBool(data['paused'], 'stream paused'));
  }

  DiscordStreamState _receiveDelete(Map<String, Object?> data) {
    return _copyWith(
      endpoint: null,
      deleteReason: _requiredValue(data['reason'], 'stream delete reason'),
    );
  }

  DiscordStreamState _copyWith({
    Object? rtcServerId = _unset,
    Object? rtcChannelId = _unset,
    Object? token = _unset,
    Object? endpoint = _unset,
    bool? paused,
    Object? deleteReason = _unset,
  }) {
    return DiscordStreamState(
      requestedStreamKey: requestedStreamKey,
      rtcServerId: identical(rtcServerId, _unset)
          ? this.rtcServerId
          : rtcServerId as String?,
      rtcChannelId: identical(rtcChannelId, _unset)
          ? this.rtcChannelId
          : rtcChannelId as String?,
      token: identical(token, _unset) ? this.token : token as String?,
      endpoint: identical(endpoint, _unset)
          ? this.endpoint
          : endpoint as String?,
      paused: paused ?? this.paused,
      deleteReason: identical(deleteReason, _unset)
          ? this.deleteReason
          : deleteReason as String?,
    );
  }
}

Map<String, Object?> _eventData(Object? value) {
  if (value is! Map) {
    throw const FormatException('stream Gateway event data가 올바르지 않습니다.');
  }
  return value.map((key, item) => MapEntry(key.toString(), item));
}

String _requiredId(Object? value, String field) {
  final id = _requiredValue(value, field);
  if (int.tryParse(id) == null) {
    throw FormatException('$field 형식이 올바르지 않습니다.');
  }
  return id;
}

String _requiredValue(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field 값이 필요합니다.');
  }
  return value.trim();
}

bool _requiredBool(Object? value, String field) {
  if (value is! bool) {
    throw FormatException('$field 형식이 올바르지 않습니다.');
  }
  return value;
}

String _normalizeEndpoint(String endpoint) {
  final normalized = endpoint
      .trim()
      .replaceFirst(RegExp(r'^wss?://'), '')
      .replaceAll(RegExp(r'/+$'), '');
  if (normalized.isEmpty) {
    throw const FormatException('stream endpoint 값이 필요합니다.');
  }
  return normalized;
}

const Object _unset = Object();
