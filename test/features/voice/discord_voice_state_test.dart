import 'package:discord_native/features/voice/domain/discord_voice_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordVoiceState', () {
    test('VOICE_STATE_UPDATE 참가자를 채널별 불변 목록으로 병합한다', () {
      const initial = DiscordVoiceState();

      final joined = initial.payloadReceived(
        _dispatch('VOICE_STATE_UPDATE', {
          'guild_id': 'guild-1',
          'channel_id': 'voice-1',
          'user_id': 'user-2',
          'session_id': 'session-2',
          'deaf': false,
          'mute': false,
          'self_deaf': false,
          'self_mute': true,
          'self_stream': false,
          'self_video': false,
          'suppress': false,
        }),
        currentUserId: 'user-1',
      );
      final moved = joined.payloadReceived(
        _dispatch('VOICE_STATE_UPDATE', {
          'guild_id': 'guild-1',
          'channel_id': 'voice-2',
          'user_id': 'user-2',
          'session_id': 'session-2',
          'deaf': false,
          'mute': false,
          'self_deaf': false,
          'self_mute': false,
          'self_stream': true,
          'self_video': true,
          'suppress': false,
        }),
        currentUserId: 'user-1',
      );

      expect(initial.participants, isEmpty);
      expect(joined.participantsForChannel('voice-1'), hasLength(1));
      expect(moved.participantsForChannel('voice-1'), isEmpty);
      expect(moved.participantsForChannel('voice-2').single.selfVideo, isTrue);
      expect(moved.participantsForChannel('voice-2').single.selfStream, isTrue);
    });

    test('server와 자신의 voice state 순서와 무관하게 연결 자격을 만든다', () {
      final joining = const DiscordVoiceState().beginJoin(
        guildId: 'guild-1',
        channelId: 'voice-1',
        selfMute: false,
        selfDeaf: true,
      );
      final withServer = joining.payloadReceived(
        _dispatch('VOICE_SERVER_UPDATE', {
          'guild_id': 'guild-1',
          'token': 'voice-token',
          'endpoint': 'rotterdam123.discord.media:443',
        }),
        currentUserId: 'user-1',
      );

      expect(withServer.phase, DiscordVoicePhase.awaitingSession);
      expect(withServer.credentials, isNull);

      final ready = withServer.payloadReceived(
        _dispatch('VOICE_STATE_UPDATE', {
          'guild_id': 'guild-1',
          'channel_id': 'voice-1',
          'user_id': 'user-1',
          'session_id': 'session-1',
          'deaf': false,
          'mute': false,
          'self_deaf': true,
          'self_mute': false,
          'self_stream': false,
          'self_video': false,
          'suppress': false,
        }),
        currentUserId: 'user-1',
      );

      expect(ready.phase, DiscordVoicePhase.connecting);
      expect(
        ready.credentials,
        const DiscordVoiceCredentials(
          guildId: 'guild-1',
          channelId: 'voice-1',
          userId: 'user-1',
          sessionId: 'session-1',
          token: 'voice-token',
          endpoint: 'rotterdam123.discord.media',
        ),
      );
    });

    test('자신의 퇴장 이벤트는 연결 정보와 요청 채널을 정리한다', () {
      final connected = _connectedState();

      final left = connected.payloadReceived(
        _dispatch('VOICE_STATE_UPDATE', {
          'guild_id': 'guild-1',
          'channel_id': null,
          'user_id': 'user-1',
          'session_id': 'session-1',
          'deaf': false,
          'mute': false,
          'self_deaf': false,
          'self_mute': false,
          'self_stream': false,
          'self_video': false,
          'suppress': false,
        }),
        currentUserId: 'user-1',
      );

      expect(left.phase, DiscordVoicePhase.disconnected);
      expect(left.guildId, isNull);
      expect(left.channelId, isNull);
      expect(left.credentials, isNull);
      expect(left.participants, isEmpty);
    });

    test('로컬 mute와 deafen 변경은 기존 상태를 수정하지 않는다', () {
      final initial = const DiscordVoiceState().beginJoin(
        guildId: 'guild-1',
        channelId: 'voice-1',
        selfMute: false,
        selfDeaf: false,
      );

      final muted = initial.withSelfAudio(selfMute: true, selfDeaf: true);

      expect(initial.selfMute, isFalse);
      expect(initial.selfDeaf, isFalse);
      expect(muted.selfMute, isTrue);
      expect(muted.selfDeaf, isTrue);
    });

    test('잘못된 voice dispatch 경계는 명확한 FormatException을 낸다', () {
      expect(
        () => const DiscordVoiceState().payloadReceived(
          _dispatch('VOICE_SERVER_UPDATE', {
            'guild_id': 'guild-1',
            'token': 12,
            'endpoint': 'rotterdam123.discord.media',
          }),
          currentUserId: 'user-1',
        ),
        throwsFormatException,
      );
    });
  });
}

DiscordVoiceState _connectedState() {
  final joining = const DiscordVoiceState().beginJoin(
    guildId: 'guild-1',
    channelId: 'voice-1',
    selfMute: false,
    selfDeaf: false,
  );
  final withServer = joining.payloadReceived(
    _dispatch('VOICE_SERVER_UPDATE', {
      'guild_id': 'guild-1',
      'token': 'voice-token',
      'endpoint': 'rotterdam123.discord.media:443',
    }),
    currentUserId: 'user-1',
  );
  return withServer.payloadReceived(
    _dispatch('VOICE_STATE_UPDATE', {
      'guild_id': 'guild-1',
      'channel_id': 'voice-1',
      'user_id': 'user-1',
      'session_id': 'session-1',
      'deaf': false,
      'mute': false,
      'self_deaf': false,
      'self_mute': false,
      'self_stream': false,
      'self_video': false,
      'suppress': false,
    }),
    currentUserId: 'user-1',
  );
}

Map<String, Object?> _dispatch(String type, Map<String, Object?> data) {
  return {'op': 0, 't': type, 'd': data};
}
