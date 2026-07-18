import 'package:cached_network_image/cached_network_image.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/conversation_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('같은 작성자의 7분 이내 연속 메시지는 header를 한 번만 표시한다', (tester) async {
    await _setSurface(tester);
    final messages = [
      _message('message-1', '첫째', minute: 0),
      _message('message-2', '둘째', minute: 1),
      _message('message-3', '셋째', minute: 6),
    ];

    await tester.pumpWidget(_conversation(messages));

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('첫째'), findsOneWidget);
    expect(find.text('둘째'), findsOneWidget);
    expect(find.text('셋째'), findsOneWidget);
  });

  testWidgets('7분 경계와 답장은 새 message group을 시작한다', (tester) async {
    await _setSurface(tester);
    final referenced = _message('referenced', '원문', minute: 0);
    final messages = [
      _message('message-1', '첫째', minute: 0),
      _message('message-2', '7분 뒤', minute: 7),
      DiscordMessage(
        id: 'message-3',
        channelId: 'channel-1',
        content: '답장',
        authorId: 'user-1',
        authorName: 'Alice',
        timestamp: DateTime.utc(2026, 7, 18, 10, 8),
        referencedMessage: referenced,
      ),
    ];

    await tester.pumpWidget(_conversation(messages));

    expect(find.text('Alice'), findsNWidgets(3));
    expect(find.text('Alice에게 답장'), findsOneWidget);
  });

  testWidgets('message author avatar hash를 CDN avatar로 렌더링한다', (tester) async {
    await _setSurface(tester);
    final message = DiscordMessage.fromJson({
      'id': 'message-avatar',
      'channel_id': 'channel-1',
      'content': 'avatar',
      'timestamp': '2026-07-18T10:00:00.000Z',
      'author': {
        'id': 'user-1',
        'username': 'alice',
        'global_name': 'Alice',
        'avatar': 'avatar-hash',
      },
    });

    await tester.pumpWidget(_conversation([message]));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final provider = avatar.foregroundImage as CachedNetworkImageProvider;
    expect(
      provider.url,
      'https://cdn.discordapp.com/avatars/user-1/avatar-hash.webp?size=128',
    );
  });
}

Future<void> _setSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _conversation(List<DiscordMessage> messages) {
  return MaterialApp(
    home: Scaffold(
      body: ConversationPanel(
        guild: const DiscordGuild(id: 'guild-1', name: 'Guild'),
        channel: const DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
        messageState: DiscordMessageState.loaded('channel-1', messages),
        typingUsers: const [],
        onTyping: null,
        currentUserId: 'user-me',
        canSendMessages: true,
        canManageMessages: false,
        canPinMessages: false,
        onSendMessage: (_) async {},
        onSendPoll: null,
        onSendSticker: null,
        onLoadOlderMessages: null,
        onSendReply: (_, _) async {},
        onToggleReaction: null,
        onVotePoll: null,
        onEditMessage: null,
        onDeleteMessage: null,
        onTogglePinned: null,
        onPickAttachments: null,
        onDownloadAttachment: null,
        onSendAttachments: null,
        onRefreshThreads: null,
        onCreateThread: null,
        onStartThreadFromMessage: null,
        onJoinThread: null,
        onSetThreadArchived: null,
        directMessageSearchQuery: '',
        onSearchDirectMessages: null,
        onClearDirectMessageSearch: null,
      ),
    ),
  );
}

DiscordMessage _message(String id, String content, {required int minute}) {
  return DiscordMessage(
    id: id,
    channelId: 'channel-1',
    content: content,
    authorId: 'user-1',
    authorName: 'Alice',
    timestamp: DateTime.utc(2026, 7, 18, 10, minute),
  );
}
