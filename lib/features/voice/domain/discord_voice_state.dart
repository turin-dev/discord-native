enum DiscordVoicePhase {
  disconnected,
  joining,
  awaitingServer,
  awaitingSession,
  connecting,
  ready,
  reconnecting,
  disconnecting,
  failed,
}

final class DiscordVoiceCredentials {
  const DiscordVoiceCredentials({
    required this.guildId,
    required this.channelId,
    required this.userId,
    required this.sessionId,
    required this.token,
    required this.endpoint,
  });

  final String guildId;
  final String channelId;
  final String userId;
  final String sessionId;
  final String token;
  final String endpoint;

  @override
  bool operator ==(Object other) {
    return other is DiscordVoiceCredentials &&
        guildId == other.guildId &&
        channelId == other.channelId &&
        userId == other.userId &&
        sessionId == other.sessionId &&
        token == other.token &&
        endpoint == other.endpoint;
  }

  @override
  int get hashCode {
    return Object.hash(guildId, channelId, userId, sessionId, token, endpoint);
  }
}

final class DiscordVoiceParticipant {
  const DiscordVoiceParticipant({
    required this.guildId,
    required this.channelId,
    required this.userId,
    required this.sessionId,
    required this.deaf,
    required this.mute,
    required this.selfDeaf,
    required this.selfMute,
    required this.selfStream,
    required this.selfVideo,
    required this.suppress,
  });

  factory DiscordVoiceParticipant.fromJson(Map<String, Object?> json) {
    return DiscordVoiceParticipant(
      guildId: _requiredString(json['guild_id'], 'voice state.guild_id'),
      channelId: _requiredString(json['channel_id'], 'voice state.channel_id'),
      userId: _requiredString(json['user_id'], 'voice state.user_id'),
      sessionId: _requiredString(json['session_id'], 'voice state.session_id'),
      deaf: _requiredBool(json['deaf'], 'voice state.deaf'),
      mute: _requiredBool(json['mute'], 'voice state.mute'),
      selfDeaf: _requiredBool(json['self_deaf'], 'voice state.self_deaf'),
      selfMute: _requiredBool(json['self_mute'], 'voice state.self_mute'),
      selfStream: json['self_stream'] == true,
      selfVideo: _requiredBool(json['self_video'], 'voice state.self_video'),
      suppress: _requiredBool(json['suppress'], 'voice state.suppress'),
    );
  }

  final String guildId;
  final String channelId;
  final String userId;
  final String sessionId;
  final bool deaf;
  final bool mute;
  final bool selfDeaf;
  final bool selfMute;
  final bool selfStream;
  final bool selfVideo;
  final bool suppress;
}

final class DiscordVoiceServer {
  const DiscordVoiceServer({
    required this.guildId,
    required this.token,
    required this.endpoint,
  });

  factory DiscordVoiceServer.fromJson(Map<String, Object?> json) {
    final rawEndpoint = json['endpoint'];
    final endpoint = switch (rawEndpoint) {
      null => null,
      final String value => _normalizeEndpoint(value),
      _ => throw const FormatException('voice server.endpoint 형식이 올바르지 않습니다.'),
    };
    return DiscordVoiceServer(
      guildId: _requiredString(json['guild_id'], 'voice server.guild_id'),
      token: _requiredString(json['token'], 'voice server.token'),
      endpoint: endpoint,
    );
  }

  final String guildId;
  final String token;
  final String? endpoint;
}

final class DiscordVoiceState {
  const DiscordVoiceState({
    this.phase = DiscordVoicePhase.disconnected,
    this.guildId,
    this.channelId,
    this.selfMute = false,
    this.selfDeaf = false,
    this.participants = const [],
    this.server,
    this.currentUserId,
    this.sessionId,
    this.errorMessage,
  });

  final DiscordVoicePhase phase;
  final String? guildId;
  final String? channelId;
  final bool selfMute;
  final bool selfDeaf;
  final List<DiscordVoiceParticipant> participants;
  final DiscordVoiceServer? server;
  final String? currentUserId;
  final String? sessionId;
  final String? errorMessage;

  DiscordVoiceCredentials? get credentials {
    final activeGuildId = guildId;
    final activeChannelId = channelId;
    final userId = currentUserId;
    final activeSessionId = sessionId;
    final activeServer = server;
    final endpoint = activeServer?.endpoint;
    if (activeGuildId == null ||
        activeChannelId == null ||
        userId == null ||
        activeSessionId == null ||
        activeServer == null ||
        activeServer.guildId != activeGuildId ||
        endpoint == null) {
      return null;
    }
    return DiscordVoiceCredentials(
      guildId: activeGuildId,
      channelId: activeChannelId,
      userId: userId,
      sessionId: activeSessionId,
      token: activeServer.token,
      endpoint: endpoint,
    );
  }

  DiscordVoiceState beginJoin({
    required String guildId,
    required String channelId,
    required bool selfMute,
    required bool selfDeaf,
  }) {
    final normalizedGuildId = _normalizeId(guildId, 'voice guild ID');
    final normalizedChannelId = _normalizeId(channelId, 'voice channel ID');
    return DiscordVoiceState(
      phase: DiscordVoicePhase.joining,
      guildId: normalizedGuildId,
      channelId: normalizedChannelId,
      selfMute: selfMute,
      selfDeaf: selfDeaf,
      participants: participants,
    );
  }

  DiscordVoiceState withSelfAudio({
    required bool selfMute,
    required bool selfDeaf,
  }) {
    return _copyWith(selfMute: selfMute, selfDeaf: selfDeaf);
  }

  DiscordVoiceState beginLeave() {
    if (channelId == null) {
      return this;
    }
    return _copyWith(phase: DiscordVoicePhase.disconnecting);
  }

  DiscordVoiceState withConnectionPhase(
    DiscordVoicePhase phase, {
    String? errorMessage,
  }) {
    return _copyWith(phase: phase, errorMessage: errorMessage);
  }

  List<DiscordVoiceParticipant> participantsForChannel(String channelId) {
    return List.unmodifiable(
      participants.where((participant) => participant.channelId == channelId),
    );
  }

  DiscordVoiceState payloadReceived(
    Map<String, Object?> payload, {
    required String? currentUserId,
  }) {
    if (payload['op'] != 0) {
      return this;
    }
    final data = _readMap(payload['d']);
    return switch (payload['t']) {
      'VOICE_STATE_UPDATE' => _receiveVoiceState(data, currentUserId),
      'VOICE_SERVER_UPDATE' => _receiveVoiceServer(data),
      _ => this,
    };
  }

  DiscordVoiceState _receiveVoiceServer(Map<String, Object?> data) {
    final nextServer = DiscordVoiceServer.fromJson(data);
    if (guildId != nextServer.guildId) {
      return this;
    }
    return _copyWith(
      server: nextServer,
      phase: _handshakePhase(
        hasServer: nextServer.endpoint != null,
        hasSession: sessionId != null,
      ),
    );
  }

  DiscordVoiceState _receiveVoiceState(
    Map<String, Object?> data,
    String? currentUserId,
  ) {
    final userId = _requiredString(data['user_id'], 'voice state.user_id');
    final rawChannelId = data['channel_id'];
    if (rawChannelId != null && rawChannelId is! String) {
      throw const FormatException('voice state.channel_id 형식이 올바르지 않습니다.');
    }
    final retained = participants
        .where((participant) => participant.userId != userId)
        .toList();
    if (rawChannelId == null) {
      if (userId != currentUserId) {
        return _copyWith(participants: retained);
      }
      return DiscordVoiceState(
        participants: List.unmodifiable(retained),
        selfMute: false,
        selfDeaf: false,
      );
    }
    final participant = DiscordVoiceParticipant.fromJson(data);
    final nextParticipants = List<DiscordVoiceParticipant>.unmodifiable([
      ...retained,
      participant,
    ]);
    if (userId != currentUserId) {
      return _copyWith(participants: nextParticipants);
    }
    final nextServer = participant.guildId == guildId ? server : null;
    return DiscordVoiceState(
      phase: _handshakePhase(
        hasServer: nextServer?.endpoint != null,
        hasSession: true,
      ),
      guildId: participant.guildId,
      channelId: participant.channelId,
      selfMute: participant.selfMute,
      selfDeaf: participant.selfDeaf,
      participants: nextParticipants,
      server: nextServer,
      currentUserId: userId,
      sessionId: participant.sessionId,
    );
  }

  DiscordVoiceState _copyWith({
    DiscordVoicePhase? phase,
    bool? selfMute,
    bool? selfDeaf,
    List<DiscordVoiceParticipant>? participants,
    DiscordVoiceServer? server,
    Object? errorMessage = _unset,
  }) {
    return DiscordVoiceState(
      phase: phase ?? this.phase,
      guildId: guildId,
      channelId: channelId,
      selfMute: selfMute ?? this.selfMute,
      selfDeaf: selfDeaf ?? this.selfDeaf,
      participants: List.unmodifiable(participants ?? this.participants),
      server: server ?? this.server,
      currentUserId: currentUserId,
      sessionId: sessionId,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

const Object _unset = Object();

DiscordVoicePhase _handshakePhase({
  required bool hasServer,
  required bool hasSession,
}) {
  if (hasServer && hasSession) {
    return DiscordVoicePhase.connecting;
  }
  if (hasServer) {
    return DiscordVoicePhase.awaitingSession;
  }
  if (hasSession) {
    return DiscordVoicePhase.awaitingServer;
  }
  return DiscordVoicePhase.joining;
}

String _normalizeEndpoint(String input) {
  var endpoint = input.trim();
  if (endpoint.isEmpty) {
    throw const FormatException('voice server.endpoint 형식이 올바르지 않습니다.');
  }
  endpoint = endpoint
      .replaceFirst(RegExp(r'^wss://'), '')
      .replaceFirst(RegExp(r'/$'), '');
  return endpoint.replaceFirst(RegExp(r':\d+$'), '');
}

String _normalizeId(String input, String field) {
  final normalized = input.trim();
  if (normalized.isEmpty) {
    throw FormatException('$field가 필요합니다.');
  }
  return normalized;
}

Map<String, Object?> _readMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const FormatException('voice dispatch data 형식이 올바르지 않습니다.');
}

String _requiredString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

bool _requiredBool(Object? value, String field) {
  if (value is bool) {
    return value;
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}
