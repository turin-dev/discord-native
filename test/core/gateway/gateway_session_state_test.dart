import 'package:discord_native/core/gateway/gateway_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GatewaySessionState', () {
    test('연결 직후 HELLO를 기다린다', () {
      final state = const GatewaySessionState.disconnected().connectionOpened();

      expect(state.phase, GatewayPhase.awaitingHello);
    });

    test('HELLO 수신 후 heartbeat 간격을 저장하고 IDENTIFY 단계로 간다', () {
      final state = const GatewaySessionState.disconnected()
          .connectionOpened()
          .payloadReceived({
            'op': 10,
            'd': {'heartbeat_interval': 41250},
          });

      expect(state.phase, GatewayPhase.identifying);
      expect(state.heartbeatInterval, const Duration(milliseconds: 41250));
    });

    test('READY 수신 후 재연결에 필요한 세션 정보를 보존한다', () {
      final state = const GatewaySessionState.disconnected()
          .connectionOpened()
          .payloadReceived({
            'op': 10,
            'd': {'heartbeat_interval': 45000},
          })
          .payloadReceived({
            'op': 0,
            's': 42,
            't': 'READY',
            'd': {
              'session_id': 'session-1',
              'resume_gateway_url': 'wss://resume.discord.gg',
            },
          });

      expect(state.phase, GatewayPhase.ready);
      expect(state.sequence, 42);
      expect(state.sessionId, 'session-1');
      expect(state.resumeGatewayUrl, 'wss://resume.discord.gg');
    });

    test('heartbeat 전송과 ACK 상태를 불변 객체로 갱신한다', () {
      final initial = const GatewaySessionState(
        phase: GatewayPhase.ready,
        heartbeatInterval: Duration(seconds: 45),
        sequence: 9,
      );

      final awaitingAck = initial.heartbeatSent();
      final acknowledged = awaitingAck.payloadReceived({'op': 11, 'd': null});

      expect(initial.awaitingHeartbeatAck, isFalse);
      expect(awaitingAck.awaitingHeartbeatAck, isTrue);
      expect(acknowledged.awaitingHeartbeatAck, isFalse);
    });

    test('세션 정보가 있는 재연결 HELLO는 RESUME 단계로 간다', () {
      final state =
          const GatewaySessionState(
            phase: GatewayPhase.reconnecting,
            sessionId: 'session-1',
            resumeGatewayUrl: 'wss://resume.discord.gg',
            sequence: 42,
          ).connectionOpened().payloadReceived({
            'op': 10,
            'd': {'heartbeat_interval': 45000},
          });

      expect(state.phase, GatewayPhase.resuming);
    });

    test('RESUMED dispatch는 ready 상태로 복귀한다', () {
      final state = const GatewaySessionState(
        phase: GatewayPhase.resuming,
        sessionId: 'session-1',
        sequence: 42,
      ).payloadReceived({'op': 0, 's': 43, 't': 'RESUMED', 'd': {}});

      expect(state.phase, GatewayPhase.ready);
      expect(state.sequence, 43);
    });

    test('resume 불가 INVALID_SESSION은 세션 정보를 제거한다', () {
      final state = const GatewaySessionState(
        phase: GatewayPhase.ready,
        sessionId: 'session-1',
        resumeGatewayUrl: 'wss://resume.discord.gg',
        sequence: 42,
      ).payloadReceived({'op': 9, 'd': false});

      expect(state.phase, GatewayPhase.reconnecting);
      expect(state.sessionId, isNull);
      expect(state.resumeGatewayUrl, isNull);
      expect(state.sequence, isNull);
    });
  });
}
