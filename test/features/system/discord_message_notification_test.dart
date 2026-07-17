import 'package:discord_native/features/system/domain/discord_message_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordMessageNotification.fromGatewayEvent', () {
    test('다른 채널의 다른 사용자 메시지를 알림으로 변환한다', () {
      final notification = DiscordMessageNotification.fromGatewayEvent(
        _messageEvent(content: '새 메시지'),
        currentUserId: 'user-1',
        selectedChannelId: 'channel-1',
      );

      expect(notification?.title, 'Alice');
      expect(notification?.body, '새 메시지');
      expect(notification?.channelId, 'channel-2');
    });

    test('현재 사용자의 메시지와 선택 채널 메시지는 제외한다', () {
      expect(
        DiscordMessageNotification.fromGatewayEvent(
          _messageEvent(content: '내 메시지', authorId: 'user-1'),
          currentUserId: 'user-1',
          selectedChannelId: 'channel-1',
        ),
        isNull,
      );
      expect(
        DiscordMessageNotification.fromGatewayEvent(
          _messageEvent(content: '보고 있는 메시지', channelId: 'channel-1'),
          currentUserId: 'user-1',
          selectedChannelId: 'channel-1',
        ),
        isNull,
      );
    });

    test('첨부만 있는 메시지는 사용자 친화적인 본문을 사용한다', () {
      final notification = DiscordMessageNotification.fromGatewayEvent(
        _messageEvent(
          content: '',
          attachments: const [
            {'id': 'attachment-1'},
          ],
        ),
        currentUserId: 'user-1',
        selectedChannelId: null,
      );

      expect(notification?.body, '첨부 파일을 보냈습니다.');
    });

    test('MESSAGE_CREATE가 아니거나 필수 필드가 없으면 제외한다', () {
      expect(
        DiscordMessageNotification.fromGatewayEvent(
          const {'op': 0, 't': 'MESSAGE_UPDATE', 'd': {}},
          currentUserId: 'user-1',
          selectedChannelId: null,
        ),
        isNull,
      );
    });
  });
}

Map<String, Object?> _messageEvent({
  required String content,
  String authorId = 'user-2',
  String channelId = 'channel-2',
  List<Map<String, Object?>> attachments = const [],
}) {
  return {
    'op': 0,
    't': 'MESSAGE_CREATE',
    'd': {
      'id': 'message-1',
      'channel_id': channelId,
      'content': content,
      'attachments': attachments,
      'author': {'id': authorId, 'username': 'alice', 'global_name': 'Alice'},
    },
  };
}
