enum GatewayPhase {
  disconnected,
  awaitingHello,
  identifying,
  resuming,
  ready,
  reconnecting,
}

final class GatewaySessionState {
  const GatewaySessionState({
    required this.phase,
    this.heartbeatInterval,
    this.sequence,
    this.sessionId,
    this.resumeGatewayUrl,
    this.awaitingHeartbeatAck = false,
  });

  const GatewaySessionState.disconnected()
    : this(phase: GatewayPhase.disconnected);

  final GatewayPhase phase;
  final Duration? heartbeatInterval;
  final int? sequence;
  final String? sessionId;
  final String? resumeGatewayUrl;
  final bool awaitingHeartbeatAck;

  bool get canResume {
    return sessionId != null && resumeGatewayUrl != null && sequence != null;
  }

  GatewaySessionState connectionOpened() {
    return copyWith(phase: GatewayPhase.awaitingHello);
  }

  GatewaySessionState heartbeatSent() {
    return copyWith(awaitingHeartbeatAck: true);
  }

  GatewaySessionState payloadReceived(Map<String, Object?> payload) {
    final nextSequence = switch (payload['s']) {
      final int value => value,
      _ => sequence,
    };
    return switch (payload['op']) {
      10 => _receiveHello(payload, nextSequence),
      11 => copyWith(sequence: nextSequence, awaitingHeartbeatAck: false),
      0 when payload['t'] == 'READY' => _receiveReady(payload, nextSequence),
      0 when payload['t'] == 'RESUMED' => copyWith(
        phase: GatewayPhase.ready,
        sequence: nextSequence,
        awaitingHeartbeatAck: false,
      ),
      7 => copyWith(phase: GatewayPhase.reconnecting, sequence: nextSequence),
      9 when payload['d'] == false => withoutSession(),
      9 => copyWith(phase: GatewayPhase.reconnecting),
      _ => copyWith(sequence: nextSequence),
    };
  }

  GatewaySessionState _receiveHello(
    Map<String, Object?> payload,
    int? nextSequence,
  ) {
    final data = _readMap(payload['d'], 'HELLO data');
    final interval = data['heartbeat_interval'];
    if (interval is! num || interval <= 0) {
      throw const FormatException('유효한 heartbeat_interval이 필요합니다.');
    }
    return copyWith(
      phase: canResume ? GatewayPhase.resuming : GatewayPhase.identifying,
      heartbeatInterval: Duration(milliseconds: interval.toInt()),
      sequence: nextSequence,
      awaitingHeartbeatAck: false,
    );
  }

  GatewaySessionState _receiveReady(
    Map<String, Object?> payload,
    int? nextSequence,
  ) {
    final data = _readMap(payload['d'], 'READY data');
    return copyWith(
      phase: GatewayPhase.ready,
      sequence: nextSequence,
      sessionId: _readString(data['session_id'], 'session_id'),
      resumeGatewayUrl: _readString(
        data['resume_gateway_url'],
        'resume_gateway_url',
      ),
      awaitingHeartbeatAck: false,
    );
  }

  GatewaySessionState withoutSession() {
    return GatewaySessionState(
      phase: GatewayPhase.reconnecting,
      heartbeatInterval: heartbeatInterval,
      awaitingHeartbeatAck: false,
    );
  }

  GatewaySessionState copyWith({
    GatewayPhase? phase,
    Object? heartbeatInterval = _unset,
    Object? sequence = _unset,
    Object? sessionId = _unset,
    Object? resumeGatewayUrl = _unset,
    bool? awaitingHeartbeatAck,
  }) {
    return GatewaySessionState(
      phase: phase ?? this.phase,
      heartbeatInterval: identical(heartbeatInterval, _unset)
          ? this.heartbeatInterval
          : heartbeatInterval as Duration?,
      sequence: identical(sequence, _unset) ? this.sequence : sequence as int?,
      sessionId: identical(sessionId, _unset)
          ? this.sessionId
          : sessionId as String?,
      resumeGatewayUrl: identical(resumeGatewayUrl, _unset)
          ? this.resumeGatewayUrl
          : resumeGatewayUrl as String?,
      awaitingHeartbeatAck: awaitingHeartbeatAck ?? this.awaitingHeartbeatAck,
    );
  }
}

const Object _unset = Object();

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

String _readString(Object? value, String field) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}
