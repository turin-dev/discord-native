import 'package:discord_native/features/video/domain/discord_stream_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('순서가 뒤바뀐 stream server/create event를 Voice 자격 정보로 합친다', () {
    const streamKey = 'guild:100:200:300';
    var state = const DiscordStreamState(requestedStreamKey: streamKey);

    state = state.receiveGatewayEvent({
      'op': 0,
      't': 'STREAM_SERVER_UPDATE',
      'd': {
        'stream_key': streamKey,
        'token': 'stream-token',
        'endpoint': 'wss://stream.discord.media:443/',
      },
    });
    expect(
      state.credentials(userId: '300', sessionId: 'voice-session'),
      isNull,
    );

    state = state.receiveGatewayEvent({
      'op': 0,
      't': 'STREAM_CREATE',
      'd': {
        'stream_key': streamKey,
        'rtc_server_id': '400',
        'rtc_channel_id': '500',
        'paused': false,
      },
    });

    final credentials = state.credentials(
      userId: '300',
      sessionId: 'voice-session',
    );
    expect(credentials?.guildId, '400');
    expect(credentials?.channelId, '500');
    expect(credentials?.token, 'stream-token');
    expect(credentials?.endpoint, 'stream.discord.media:443');
  });

  test('stream update와 delete는 pause와 종료 이유를 보존한다', () {
    const streamKey = 'guild:100:200:300';
    var state = const DiscordStreamState(requestedStreamKey: streamKey);

    state = state.receiveGatewayEvent({
      'op': 0,
      't': 'STREAM_UPDATE',
      'd': {'stream_key': streamKey, 'paused': true},
    });
    expect(state.paused, isTrue);

    state = state.receiveGatewayEvent({
      'op': 0,
      't': 'STREAM_DELETE',
      'd': {'stream_key': streamKey, 'reason': 'stream_full'},
    });
    expect(state.deleteReason, 'stream_full');
  });
}
