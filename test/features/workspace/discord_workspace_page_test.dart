import 'dart:ui';

import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_permissions.dart';
import 'package:discord_native/features/workspace/data/read_state_repository.dart';
import 'package:discord_native/features/workspace/data/discord_channel_management_repository.dart';
import 'package:discord_native/features/workspace/data/discord_role_repository.dart';
import 'package:discord_native/features/workspace/data/discord_invite_repository.dart';
import 'package:discord_native/features/workspace/data/discord_scheduled_event_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_scheduled_event.dart';
import 'package:discord_native/features/workspace/presentation/discord_workspace_page.dart';
import 'package:discord_native/features/workspace/presentation/thread_controls.dart';
import 'package:discord_native/features/workspace/presentation/workspace_navigation.dart';
import 'package:discord_native/features/workspace/presentation/workspace_right_panel.dart';
import 'package:discord_native/features/messages/domain/discord_message_search_state.dart';
import 'package:discord_native/features/messages/domain/discord_pinned_messages_state.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/messages/domain/discord_typing_state.dart';
import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TestGesture? activeMouseGesture;

Future<void> hoverMessage(WidgetTester tester, String content) async {
  await activeMouseGesture?.removePointer();
  activeMouseGesture = null;
  final message = find.text(content);
  await tester.ensureVisible(message);
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  activeMouseGesture = gesture;
  addTearDown(() async {
    if (identical(activeMouseGesture, gesture)) {
      await gesture.removePointer();
      activeMouseGesture = null;
    }
  });
  await gesture.addPointer(location: tester.getCenter(message));
  await tester.pump();
}

Future<void> tapPopupItem(WidgetTester tester, String label) async {
  final item = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate(
      (widget) => widget is PopupMenuItem || widget is MenuItemButton,
    ),
  );
  expect(item, findsOneWidget);
  await tester.tap(item);
}

void main() {
  testWidgets('Discord desktop와 같은 shell 밀도와 title bar를 사용한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [
        DiscordGuild(id: 'guild-1', name: '개발 서버'),
        DiscordGuild(id: 'guild-2', name: '게임 서버'),
      ],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
          topic: '팀이 모이는 공간',
        ),
      ],
      currentUser: const DiscordUser(id: 'user-1', username: 'native-user'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('discord-title-bar')), findsOneWidget);
    expect(tester.getSize(find.byType(GuildRail)).width, 72);
    expect(tester.getSize(find.byType(ChannelSidebar)).width, 240);
    expect(tester.getSize(find.byType(ThreadConversationHeader)).height, 48);
    expect(tester.getSize(find.byType(WorkspaceRightPanel)).width, 240);
    expect(find.text('팀이 모이는 공간'), findsOneWidget);
  });

  testWidgets('guild rail과 선택한 guild의 채널을 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [
        DiscordGuild(id: 'guild-1', name: '개발 서버'),
        DiscordGuild(id: 'guild-2', name: '게임 서버'),
      ],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
      currentUser: const DiscordUser(id: 'user-1', username: 'native-user'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('guild-rail-guild-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('guild-rail-guild-2')), findsOneWidget);
    expect(find.text('general'), findsWidgets);
    expect(find.text('native-user'), findsOneWidget);
    expect(find.text('연결됨'), findsOneWidget);
  });

  testWidgets('guild와 channel 선택 callback을 전달한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? selectedGuildId;
    String? selectedChannelId;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [
        DiscordGuild(id: 'guild-1', name: '개발 서버'),
        DiscordGuild(id: 'guild-2', name: '게임 서버'),
      ],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (id) => selectedGuildId = id,
          onSelectChannel: (id) => selectedChannelId = id,
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('guild-rail-guild-2')));
    await tester.tap(find.text('general').first);

    expect(selectedGuildId, 'guild-2');
    expect(selectedChannelId, 'channel-1');
  });

  testWidgets('category 아래 channel과 thread를 트리로 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: [
        const DiscordChannel(
          id: 'category-1',
          guildId: 'guild-1',
          name: '개발',
          type: 4,
          position: 0,
        ),
        const DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 1,
          parentId: 'category-1',
        ),
        DiscordChannel(
          id: 'thread-1',
          guildId: 'guild-1',
          name: '설계 토론',
          type: 11,
          position: 0,
          parentId: 'channel-1',
          threadMetadata: DiscordThreadMetadata(
            archived: false,
            locked: false,
            autoArchiveDuration: 1440,
            archiveTimestamp: DateTime.utc(2026, 7, 16, 10),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('개발'), findsOneWidget);
    expect(find.byKey(const ValueKey('category-category-1')), findsOneWidget);
    expect(find.text('general'), findsWidgets);
    expect(find.text('설계 토론'), findsOneWidget);
  });

  testWidgets('메시지 목록을 표시하고 composer 내용을 전송한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? submittedContent;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
    );
    final messageState = DiscordMessageState.loaded('channel-1', [
      DiscordMessage(
        id: 'message-1',
        channelId: 'channel-1',
        content: '기존 메시지',
        authorId: 'user-1',
        authorName: 'alice',
        timestamp: DateTime.utc(2026, 7, 16, 10),
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          messageState: messageState,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onSendMessage: (content) async {
            submittedContent = content;
          },
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('alice'), findsOneWidget);
    expect(find.text('기존 메시지'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('message-composer-field')),
      '새 메시지',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(submittedContent, '새 메시지');
  });

  testWidgets('reply, attachment, reaction을 렌더링한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? replyTargetId;
    String? toggledEmoji;
    String? downloadedAttachmentId;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
    );
    final referenced = DiscordMessage(
      id: 'message-1',
      channelId: 'channel-1',
      content: '원문',
      authorId: 'user-1',
      authorName: 'alice',
      timestamp: DateTime.utc(2026, 7, 16, 10),
    );
    final messageState = DiscordMessageState.loaded('channel-1', [
      DiscordMessage(
        id: 'message-2',
        channelId: 'channel-1',
        content: '답장',
        authorId: 'user-2',
        authorName: 'bob',
        timestamp: DateTime.utc(2026, 7, 16, 10, 1),
        referencedMessage: referenced,
        attachments: const [
          DiscordAttachment(
            id: 'attachment-1',
            filename: 'image.png',
            url: 'https://cdn.discordapp.com/image.png',
            proxyUrl: 'https://media.discordapp.net/image.png',
            size: 1024,
            contentType: 'image/png',
            width: 320,
            height: 200,
          ),
        ],
        reactions: const [DiscordReaction(emojiName: '👍', count: 2, me: true)],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          messageState: messageState,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onSendReply: (content, messageId) async {
            replyTargetId = messageId;
          },
          onToggleReaction: (message, reaction) async {
            toggledEmoji = reaction.key;
          },
          onDownloadAttachment: (attachment) async {
            downloadedAttachmentId = attachment.id;
            return r'C:\Downloads\image.png';
          },
          onLogout: () {},
        ),
      ),
    );

    expect(find.textContaining('alice'), findsOneWidget);
    expect(find.text('원문'), findsOneWidget);
    expect(find.text('image.png'), findsOneWidget);
    expect(find.text('👍 2'), findsOneWidget);

    await tester.tap(find.byTooltip('첨부 파일 다운로드'));
    await tester.pumpAndSettle();
    expect(find.text('image.png 저장 완료'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('👍 2'));
    await hoverMessage(tester, '답장');
    await tester.tap(find.byTooltip('답장'));
    await tester.enterText(
      find.byKey(const ValueKey('message-composer-field')),
      '새 답장',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(toggledEmoji, '👍');
    expect(replyTargetId, 'message-2');
    expect(downloadedAttachmentId, 'attachment-1');
  });

  testWidgets('markdown, spoiler, embed, sticker와 mention을 렌더링한다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
    );
    final message = DiscordMessage.fromJson({
      'id': 'message-rich',
      'channel_id': 'channel-1',
      'content':
          '**굵게**와 `inline`\n\n```dart\nprint("hello");\n```\n||비밀|| <@user-2> <:party:emoji-1>',
      'timestamp': '2026-07-16T10:03:00.000Z',
      'author': {'id': 'user-1', 'username': 'alice'},
      'mentions': [
        {'id': 'user-2', 'username': 'bob', 'global_name': '밥'},
      ],
      'embeds': [
        {
          'title': 'Flutter',
          'description': 'Windows 네이티브 클라이언트',
          'fields': [
            {'name': '상태', 'value': '개발 중', 'inline': true},
          ],
          'footer': {'text': 'Discord Native'},
        },
      ],
      'sticker_items': [
        {'id': 'sticker-1', 'name': 'Wumpus', 'format_type': 1},
        {'id': 'sticker-2', 'name': 'Animated Wumpus', 'format_type': 3},
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          messageState: DiscordMessageState.loaded('channel-1', [message]),
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.textContaining('굵게', findRichText: true), findsWidgets);
    expect(find.textContaining('print("hello");'), findsOneWidget);
    expect(find.textContaining('@밥', findRichText: true), findsWidgets);
    expect(find.byKey(const ValueKey('custom-emoji-emoji-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('spoiler-hidden')), findsOneWidget);
    expect(find.byKey(const ValueKey('embed-message-rich-0')), findsOneWidget);
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('개발 중'), findsOneWidget);
    expect(find.byKey(const ValueKey('sticker-sticker-1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sticker-lottie-sticker-2')),
      findsOneWidget,
    );

    final spoiler = find.byKey(const ValueKey('spoiler-hidden'));
    await Scrollable.ensureVisible(tester.element(spoiler), alignment: 0.5);
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(spoiler);
    await tester.pump();

    expect(find.byKey(const ValueKey('spoiler-revealed')), findsOneWidget);
    expect(find.text('비밀'), findsOneWidget);
  });

  testWidgets('Discord CDN image link를 filename과 inline media로 렌더링한다', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
    );
    final messages = [
      DiscordMessage.fromJson({
        'id': 'message-attachment-source',
        'channel_id': 'channel-1',
        'content': '',
        'timestamp': '2026-07-18T14:00:00.000Z',
        'author': {'id': 'user-2', 'username': 'bob'},
        'attachments': [
          {
            'id': 'attachment-1',
            'filename': 'X.gif',
            'url':
                'https://cdn.discordapp.com/attachments/channel-1/attachment-1/X.gif?signature=current',
            'proxy_url':
                'https://media.discordapp.net/attachments/channel-1/attachment-1/X.gif?signature=current&width=400',
            'size': 1024,
            'content_type': 'image/gif',
            'width': 400,
            'height': 225,
          },
        ],
      }),
      DiscordMessage.fromJson({
        'id': 'message-media',
        'channel_id': 'channel-1',
        'content':
            '<@user-2> https://cdn.discordapp.com/attachments/channel-1/attachment-1/X.gif',
        'timestamp': '2026-07-18T14:01:00.000Z',
        'author': {'id': 'user-1', 'username': 'alice'},
        'mentions': [
          {'id': 'user-2', 'username': 'bob', 'global_name': '밥'},
        ],
      }),
      DiscordMessage.fromJson({
        'id': 'message-external',
        'channel_id': 'channel-1',
        'content': 'https://example.com/image.gif',
        'timestamp': '2026-07-18T14:02:00.000Z',
        'author': {'id': 'user-1', 'username': 'alice'},
      }),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          messageState: DiscordMessageState.loaded('channel-1', messages),
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.textContaining('@밥', findRichText: true), findsWidgets);
    expect(find.textContaining('X.gif', findRichText: true), findsWidgets);
    expect(
      find.textContaining('https://cdn.discordapp.com', findRichText: true),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('discord-media-link-message-media-0')),
      findsOneWidget,
    );
    final mediaPreview = find.byKey(
      const ValueKey('discord-media-link-message-media-0'),
    );
    final mediaImage = tester.widget<CachedNetworkImage>(
      find.descendant(
        of: mediaPreview,
        matching: find.byType(CachedNetworkImage),
      ),
    );
    expect(
      mediaImage.imageUrl,
      'https://media.discordapp.net/attachments/channel-1/attachment-1/X.gif?signature=current&width=400',
    );
    expect(
      find.textContaining('https://example.com/image.gif', findRichText: true),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('discord-media-link-message-external-0')),
      findsNothing,
    );
  });

  testWidgets('파일을 선택하고 multipart 전송 callback으로 전달한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    List<DiscordUploadFile>? uploadedFiles;
    String? uploadedReplyTargetId;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
    );
    final messageState = DiscordMessageState(
      messages: [
        DiscordMessage(
          id: 'message-1',
          channelId: 'channel-1',
          content: '원문',
          authorId: 'user-1',
          authorName: 'alice',
          timestamp: DateTime.utc(2026, 7, 16, 10),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          messageState: messageState,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onPickAttachments: () async => const [
            DiscordUploadFile(
              filename: 'image.png',
              bytes: [1, 2, 3],
              contentType: 'image/png',
            ),
          ],
          onSendAttachments:
              (content, files, {String? replyToMessageId}) async {
                uploadedFiles = files;
                uploadedReplyTargetId = replyToMessageId;
              },
          onLogout: () {},
        ),
      ),
    );

    await hoverMessage(tester, '원문');
    await tester.tap(find.byTooltip('답장'));
    await tester.tap(find.byTooltip('파일 첨부'));
    await tester.pump();
    expect(find.text('image.png'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(uploadedFiles?.single.filename, 'image.png');
    expect(uploadedReplyTargetId, 'message-1');
  });

  testWidgets('thread 표시와 생성·참여·보관 callback을 전달한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? refreshedParentId;
    String? createdName;
    String? startedMessageId;
    String? startedName;
    String? joinedThreadId;
    String? archivedThreadId;
    bool? archivedValue;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: [
        const DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
        DiscordChannel(
          id: 'thread-1',
          guildId: 'guild-1',
          name: '설계 토론',
          type: 11,
          position: 0,
          parentId: 'channel-1',
          threadMetadata: DiscordThreadMetadata(
            archived: false,
            locked: false,
            autoArchiveDuration: 1440,
            archiveTimestamp: DateTime.utc(2026, 7, 16, 10),
          ),
        ),
      ],
    );
    final messageState = DiscordMessageState(
      channelId: 'channel-1',
      messages: [
        DiscordMessage(
          id: 'message-1',
          channelId: 'channel-1',
          content: '원문',
          authorId: 'user-1',
          authorName: 'alice',
          timestamp: DateTime.utc(2026, 7, 16, 10),
        ),
      ],
    );

    Widget page(String selectedChannelId) {
      return MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          messageState: messageState,
          selectedGuildId: 'guild-1',
          selectedChannelId: selectedChannelId,
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onRefreshThreads: (parentId) async {
            refreshedParentId = parentId;
          },
          onCreateThread: (parentId, name) async {
            createdName = name;
          },
          onStartThreadFromMessage: (messageId, name) async {
            startedMessageId = messageId;
            startedName = name;
          },
          onJoinThread: (threadId) async {
            joinedThreadId = threadId;
          },
          onSetThreadArchived: (threadId, archived) async {
            archivedThreadId = threadId;
            archivedValue = archived;
          },
          onLogout: () {},
        ),
      );
    }

    await tester.pumpWidget(page('channel-1'));

    expect(find.text('설계 토론'), findsOneWidget);
    await tester.tap(find.byTooltip('스레드 새로고침'));
    await tester.tap(find.byTooltip('스레드 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('thread-name-field')),
      '새 스레드',
    );
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();
    await hoverMessage(tester, '원문');
    await tester.tap(find.byTooltip('스레드 시작'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('thread-name-field')),
      '원문 토론',
    );
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(refreshedParentId, 'channel-1');
    expect(createdName, '새 스레드');
    expect(startedMessageId, 'message-1');
    expect(startedName, '원문 토론');

    await tester.pumpWidget(page('thread-1'));
    await tester.tap(find.byTooltip('스레드 참여'));
    await tester.tap(find.byTooltip('스레드 보관'));
    await tester.pump();

    expect(joinedThreadId, 'thread-1');
    expect(archivedThreadId, 'thread-1');
    expect(archivedValue, isTrue);
  });

  testWidgets('guild 메시지를 검색하고 결과 선택 callback을 전달한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? searchedQuery;
    bool? searchedCurrentChannelOnly;
    String? selectedMessageId;
    var clearCount = 0;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
        DiscordChannel(
          id: 'channel-2',
          guildId: 'guild-1',
          name: 'random',
          type: 0,
          position: 1,
        ),
      ],
    );
    final result = DiscordMessage(
      id: 'message-search',
      channelId: 'channel-2',
      content: '검색 결과 본문',
      authorId: 'user-1',
      authorName: 'alice',
      timestamp: DateTime.utc(2026, 7, 16, 10),
    );
    final searchState = DiscordMessageSearchState.loaded(
      query: '기존 검색',
      totalResults: 1,
      messages: [result],
      currentChannelOnly: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          searchState: searchState,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onSearchMessages: (query, currentChannelOnly) async {
            searchedQuery = query;
            searchedCurrentChannelOnly = currentChannelOnly;
          },
          onSelectSearchResult: (message) async {
            selectedMessageId = message.id;
          },
          onClearSearch: () => clearCount += 1,
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('검색 결과 본문'), findsOneWidget);
    expect(find.text('alice · #random'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('current-channel-only')));
    await tester.enterText(
      find.byKey(const ValueKey('message-search-field')),
      '새 검색',
    );
    await tester.tap(find.byTooltip('메시지 검색 실행'));
    await tester.tap(find.text('검색 결과 본문'));
    await tester.tap(find.byTooltip('검색 지우기'));
    await tester.pump();

    expect(searchedQuery, '새 검색');
    expect(searchedCurrentChannelOnly, isTrue);
    expect(selectedMessageId, 'message-search');
    expect(clearCount, 1);
  });

  testWidgets('소유한 메시지를 편집하고 고정하고 삭제한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? editedContent;
    String? pinnedMessageId;
    String? deletedMessageId;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
      currentUser: const DiscordUser(id: 'user-1', username: 'alice'),
    );
    final message = DiscordMessage(
      id: 'message-1',
      channelId: 'channel-1',
      content: '원본 메시지',
      authorId: 'user-1',
      authorName: 'alice',
      timestamp: DateTime.utc(2026, 7, 16, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          messageState: DiscordMessageState.loaded('channel-1', [message]),
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onEditMessage: (target, content) async {
            expect(target.id, 'message-1');
            editedContent = content;
          },
          onTogglePinned: (target) async {
            pinnedMessageId = target.id;
          },
          onDeleteMessage: (target) async {
            deletedMessageId = target.id;
          },
          onLogout: () {},
        ),
      ),
    );

    await hoverMessage(tester, '원본 메시지');
    await tester.tap(find.byTooltip('메시지 작업'));
    await tester.pumpAndSettle();
    await tapPopupItem(tester, '편집');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('message-edit-field')),
      '수정된 메시지',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    await hoverMessage(tester, '원본 메시지');
    await tester.tap(find.byTooltip('메시지 작업'));
    await tester.pumpAndSettle();
    await tapPopupItem(tester, '고정');
    await tester.pumpAndSettle();

    await hoverMessage(tester, '원본 메시지');
    await tester.tap(find.byTooltip('메시지 작업'));
    await tester.pumpAndSettle();
    await tapPopupItem(tester, '삭제');
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(editedContent, '수정된 메시지');
    expect(pinnedMessageId, 'message-1');
    expect(deletedMessageId, 'message-1');
  });

  testWidgets('과거 메시지 pagination callback을 전달한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var loadCount = 0;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
    );
    final message = DiscordMessage(
      id: 'message-1',
      channelId: 'channel-1',
      content: '현재 메시지',
      authorId: 'user-1',
      authorName: 'alice',
      timestamp: DateTime.utc(2026, 7, 16, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          messageState: DiscordMessageState.loaded('channel-1', [
            message,
          ], hasMore: true),
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLoadOlderMessages: () async => loadCount += 1,
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.text('이전 메시지 불러오기'));
    await tester.pump();

    expect(loadCount, 1);
  });

  testWidgets('typing 사용자를 표시하고 composer 입력 callback을 전달한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var typingCount = 0;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          typingUsers: [
            DiscordTypingUser(
              channelId: 'channel-1',
              userId: 'user-2',
              displayName: '밥',
              expiresAt: DateTime.utc(2026, 7, 16, 10, 0, 10),
            ),
          ],
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onSendMessage: (_) async {},
          onTyping: () => typingCount += 1,
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('밥님이 입력 중...'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('message-composer-field')),
      '안녕하세요',
    );
    await tester.pump();

    expect(typingCount, 1);
  });

  testWidgets('guild member presence와 profile card를 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workspace = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
    );
    final people = const DiscordPeopleState().payloadReceived({
      'op': 0,
      't': 'GUILD_CREATE',
      'd': {
        'id': 'guild-1',
        'members': [
          {
            'nick': '밥',
            'roles': ['role-1'],
            'user': {'id': 'user-2', 'username': 'bob'},
          },
        ],
        'presences': [
          {
            'user': {'id': 'user-2'},
            'guild_id': 'guild-1',
            'status': 'online',
            'activities': [
              {'name': 'Flutter'},
            ],
          },
        ],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: workspace,
          peopleState: people,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.text('멤버'));
    await tester.pumpAndSettle();
    expect(find.text('밥'), findsOneWidget);
    expect(find.text('온라인 · Flutter'), findsOneWidget);

    await tester.tap(find.text('밥'));
    await tester.pumpAndSettle();
    expect(find.text('사용자 프로필'), findsOneWidget);
    expect(find.text('@bob'), findsOneWidget);
  });

  testWidgets('DM 채널과 친구·요청 상태를 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final workspace = const DiscordWorkspaceState().payloadReceived({
      'op': 0,
      't': 'READY',
      'd': {
        'user': {'id': 'user-1', 'username': 'alice'},
        'guilds': [],
        'relationships': [
          {
            'id': 'user-2',
            'type': 1,
            'nickname': '밥',
            'user': {'id': 'user-2', 'username': 'bob'},
          },
          {
            'id': 'user-3',
            'type': 3,
            'user': {'id': 'user-3', 'username': 'carol'},
          },
        ],
        'private_channels': [
          {
            'id': 'dm-1',
            'type': 1,
            'recipients': [
              {'id': 'user-2', 'username': 'bob'},
            ],
          },
        ],
      },
    });
    final people = const DiscordPeopleState().payloadReceived({
      'op': 0,
      't': 'READY',
      'd': {
        'relationships': [
          {
            'id': 'user-2',
            'type': 1,
            'nickname': '밥',
            'user': {'id': 'user-2', 'username': 'bob'},
          },
          {
            'id': 'user-3',
            'type': 3,
            'user': {'id': 'user-3', 'username': 'carol'},
          },
        ],
        'private_channels': [],
        'presences': [],
      },
    });
    String? requestedUsername;
    String? acceptedUserId;
    String? openedUserId;

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: workspace,
          peopleState: people,
          selectedGuildId: discordDirectMessagesGuildId,
          selectedChannelId: 'dm-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onSendFriendRequest: (username) async {
            requestedUsername = username;
          },
          onAcceptFriendRequest: (relationship) async {
            acceptedUserId = relationship.user.id;
          },
          onOpenDirectMessage: (relationship) async {
            openedUserId = relationship.user.id;
          },
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('다이렉트 메시지'), findsWidgets);
    expect(find.text('bob'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('direct-messages-friends')));
    await tester.pumpAndSettle();
    expect(find.text('밥'), findsWidgets);
    await tester.tap(find.byTooltip('메시지 보내기').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('친구 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('friend-request-field')),
      'new.friend',
    );
    await tester.tap(find.text('요청 보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('요청'));
    await tester.pumpAndSettle();
    expect(find.text('carol'), findsOneWidget);
    expect(find.text('받은 친구 요청'), findsOneWidget);
    await tester.tap(find.byTooltip('친구 요청 수락'));
    await tester.pumpAndSettle();

    expect(requestedUsername, 'new.friend');
    expect(acceptedUserId, 'user-3');
    expect(openedUserId, 'user-2');
  });

  testWidgets('DM header에서 고정 메시지 panel을 열고 문맥으로 이동한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final workspace = const DiscordWorkspaceState().payloadReceived({
      'op': 0,
      't': 'READY',
      'd': {
        'user': {'id': 'user-1', 'username': 'alice'},
        'guilds': [],
        'relationships': [],
        'private_channels': [
          {
            'id': 'dm-1',
            'type': 1,
            'recipients': [
              {'id': 'user-2', 'username': 'bob'},
            ],
          },
        ],
      },
    });
    final pin = DiscordMessagePin(
      pinnedAt: DateTime.utc(2026, 7, 18, 11),
      message: DiscordMessage(
        id: 'message-pin-1',
        channelId: 'dm-1',
        content: '릴리스 전에 확인할 내용',
        authorId: 'user-2',
        authorName: 'bob',
        timestamp: DateTime.utc(2026, 7, 18, 10),
        pinned: true,
      ),
    );
    var pinnedState = const DiscordPinnedMessagesState();
    String? selectedMessageId;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => DiscordWorkspacePage(
            state: workspace,
            pinnedMessagesState: pinnedState,
            selectedGuildId: discordDirectMessagesGuildId,
            selectedChannelId: 'dm-1',
            connectionLabel: '연결됨',
            onSelectGuild: (_) {},
            onSelectChannel: (_) {},
            onTogglePinnedMessages: () {
              setState(() {
                pinnedState = DiscordPinnedMessagesState.loaded(
                  channelId: 'dm-1',
                  pins: [pin],
                  hasMore: false,
                );
              });
            },
            onClosePinnedMessages: () {
              setState(() => pinnedState = const DiscordPinnedMessagesState());
            },
            onSelectPinnedMessage: (message) async {
              selectedMessageId = message.id;
            },
            onLogout: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('고정된 메시지 보기'));
    await tester.pump();

    expect(find.byKey(const ValueKey('pinned-messages-panel')), findsOneWidget);
    expect(find.text('고정된 메시지'), findsOneWidget);
    expect(find.text('릴리스 전에 확인할 내용'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('pinned-messages-panel'))).width,
      240,
    );

    await tester.tap(find.text('릴리스 전에 확인할 내용'));
    await tester.tap(find.byTooltip('고정 메시지 닫기'));
    await tester.pump();

    expect(selectedMessageId, 'message-pin-1');
    expect(find.byKey(const ValueKey('pinned-messages-panel')), findsNothing);
  });

  testWidgets('채널과 thread의 로컬 unread badge를 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = DiscordWorkspaceState.fromCollections(
      guilds: const [DiscordGuild(id: 'guild-1', name: '개발 서버')],
      channels: [
        const DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
        DiscordChannel(
          id: 'thread-1',
          guildId: 'guild-1',
          name: '설계 토론',
          type: 11,
          position: 0,
          parentId: 'channel-1',
          threadMetadata: DiscordThreadMetadata(
            archived: false,
            locked: false,
            autoArchiveDuration: 1440,
            archiveTimestamp: DateTime.utc(2026, 7, 16, 10),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          readStates: {
            'channel-1': DiscordReadState(
              channelId: 'channel-1',
              lastReadMessageId: 'message-1',
              unreadCount: 3,
              updatedAt: DateTime.utc(2026, 7, 16, 10),
            ),
            'thread-1': DiscordReadState(
              channelId: 'thread-1',
              lastReadMessageId: null,
              unreadCount: 1,
              updatedAt: DateTime.utc(2026, 7, 16, 10),
            ),
          },
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('unread-channel-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('unread-thread-1')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('현재 member 권한으로 채널과 메시지 작업을 제한한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final state = DiscordWorkspaceState.fromCollections(
      guilds: [
        DiscordGuild(
          id: 'guild-1',
          name: '개발 서버',
          roles: [
            DiscordRole(
              id: 'guild-1',
              name: '@everyone',
              position: 0,
              permissions: DiscordPermissions.viewChannel,
            ),
            DiscordRole(
              id: 'role-moderator',
              name: '운영진',
              position: 1,
              permissions:
                  DiscordPermissions.manageMessages |
                  DiscordPermissions.pinMessages,
            ),
          ],
        ),
      ],
      channels: [
        const DiscordChannel(
          id: 'channel-public',
          guildId: 'guild-1',
          name: '공개 채널',
          type: 0,
          position: 0,
        ),
        DiscordChannel(
          id: 'channel-private',
          guildId: 'guild-1',
          name: '비공개 채널',
          type: 0,
          position: 1,
          permissionOverwrites: [
            DiscordPermissionOverwrite(
              id: 'guild-1',
              type: DiscordPermissionOverwriteType.role,
              allow: BigInt.zero,
              deny: DiscordPermissions.viewChannel,
            ),
          ],
        ),
      ],
      currentUser: const DiscordUser(id: 'user-1', username: 'alice'),
    );
    final peopleState = const DiscordPeopleState().payloadReceived({
      'op': 0,
      't': 'GUILD_CREATE',
      'd': {
        'id': 'guild-1',
        'members': [
          {
            'roles': ['role-moderator'],
            'user': {'id': 'user-1', 'username': 'alice'},
          },
        ],
        'presences': [],
      },
    });
    final message = DiscordMessage(
      id: 'message-1',
      channelId: 'channel-public',
      content: '운영 대상 메시지',
      authorId: 'user-2',
      authorName: 'bob',
      timestamp: DateTime.utc(2026, 7, 17, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          peopleState: peopleState,
          messageState: DiscordMessageState.loaded('channel-public', [message]),
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-public',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onSendMessage: (_) async {},
          onDeleteMessage: (_) async {},
          onTogglePinned: (_) async {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('공개 채널'), findsWidgets);
    expect(find.text('비공개 채널'), findsNothing);
    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('message-composer-field')),
    );
    expect(composer.enabled, isFalse);

    await hoverMessage(tester, '운영 대상 메시지');
    await tester.tap(find.byTooltip('메시지 작업'));
    await tester.pumpAndSettle();
    expect(find.text('편집'), findsNothing);
    expect(find.text('고정'), findsOneWidget);
    expect(find.text('삭제'), findsOneWidget);
  });

  testWidgets('MANAGE_CHANNELS 권한으로 channel 생성·편집·삭제를 요청한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    DiscordCreateChannelRequest? createdRequest;
    DiscordUpdateChannelRequest? updatedRequest;
    String? updatedChannelId;
    String? deletedChannelId;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: [
        DiscordGuild(
          id: 'guild-1',
          name: '개발 서버',
          roles: [
            DiscordRole(
              id: 'guild-1',
              name: '@everyone',
              position: 0,
              permissions:
                  DiscordPermissions.viewChannel |
                  DiscordPermissions.sendMessages |
                  DiscordPermissions.manageChannels,
            ),
          ],
        ),
      ],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
          topic: '기존 topic',
        ),
      ],
      currentUser: const DiscordUser(id: 'user-1', username: 'alice'),
    );
    final peopleState = const DiscordPeopleState().payloadReceived({
      'op': 0,
      't': 'GUILD_CREATE',
      'd': {
        'id': 'guild-1',
        'members': [
          {
            'roles': [],
            'user': {'id': 'user-1', 'username': 'alice'},
          },
        ],
        'presences': [],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          peopleState: peopleState,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onCreateGuildChannel: (request) async {
            createdRequest = request;
          },
          onUpdateGuildChannel: (channelId, request) async {
            updatedChannelId = channelId;
            updatedRequest = request;
          },
          onDeleteGuildChannel: (channelId) async {
            deletedChannelId = channelId;
          },
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('채널 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('channel-name-field')),
      '새 채널',
    );
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(createdRequest?.name, '새 채널');
    expect(createdRequest?.type, DiscordGuildChannelType.text);

    await tester.tap(find.byTooltip('general 채널 설정'));
    await tester.pumpAndSettle();
    await tapPopupItem(tester, '채널 편집');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('channel-name-field')),
      'renamed',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(updatedChannelId, 'channel-1');
    expect(updatedRequest?.name, 'renamed');

    await tester.tap(find.byTooltip('general 채널 설정'));
    await tester.pumpAndSettle();
    await tapPopupItem(tester, '채널 삭제');
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(deletedChannelId, 'channel-1');
  });

  testWidgets('MANAGE_ROLES 권한으로 role 생성·편집·삭제를 요청한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    DiscordRoleRequest? createdRequest;
    DiscordRoleRequest? updatedRequest;
    String? updatedRoleId;
    String? deletedRoleId;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: [
        DiscordGuild(
          id: 'guild-1',
          name: '개발 서버',
          roles: [
            DiscordRole(
              id: 'guild-1',
              name: '@everyone',
              position: 0,
              permissions:
                  DiscordPermissions.viewChannel |
                  DiscordPermissions.manageRoles,
            ),
            DiscordRole(
              id: 'role-1',
              name: '운영진',
              position: 1,
              permissions: DiscordPermissions.manageMessages,
            ),
          ],
        ),
      ],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
      currentUser: const DiscordUser(id: 'user-1', username: 'alice'),
    );
    final peopleState = const DiscordPeopleState().payloadReceived({
      'op': 0,
      't': 'GUILD_CREATE',
      'd': {
        'id': 'guild-1',
        'members': [
          {
            'roles': [],
            'user': {'id': 'user-1', 'username': 'alice'},
          },
        ],
        'presences': [],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          peopleState: peopleState,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onCreateGuildRole: (request) async {
            createdRequest = request;
          },
          onUpdateGuildRole: (roleId, request) async {
            updatedRoleId = roleId;
            updatedRequest = request;
          },
          onUpdateGuildRolePositions: (_) async {},
          onDeleteGuildRole: (roleId) async {
            deletedRoleId = roleId;
          },
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('서버 설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('역할 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('role-name-field')),
      '새 역할',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(createdRequest?.name, '새 역할');

    await tester.tap(find.byTooltip('운영진 역할 설정'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('role-name-field')),
      '관리자',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(updatedRoleId, 'role-1');
    expect(updatedRequest?.name, '관리자');

    await tester.tap(find.byTooltip('운영진 역할 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(deletedRoleId, 'role-1');
  });

  testWidgets('MANAGE_GUILD 권한으로 invite 목록·생성·삭제를 요청한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? createdChannelId;
    DiscordInviteRequest? createdRequest;
    String? deletedCode;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: [
        DiscordGuild(
          id: 'guild-1',
          name: '개발 서버',
          roles: [
            DiscordRole(
              id: 'guild-1',
              name: '@everyone',
              position: 0,
              permissions:
                  DiscordPermissions.viewChannel |
                  DiscordPermissions.manageGuild |
                  DiscordPermissions.createInstantInvite,
            ),
          ],
        ),
      ],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
      currentUser: const DiscordUser(id: 'user-1', username: 'alice'),
    );
    final peopleState = const DiscordPeopleState().payloadReceived({
      'op': 0,
      't': 'GUILD_CREATE',
      'd': {
        'id': 'guild-1',
        'members': [
          {
            'roles': [],
            'user': {'id': 'user-1', 'username': 'alice'},
          },
        ],
        'presences': [],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          peopleState: peopleState,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLoadGuildInvites: () async => const [
            DiscordGuildInvite(
              code: 'abc123',
              channelId: 'channel-1',
              channelName: 'general',
              uses: 1,
              maxUses: 10,
              maxAgeSeconds: 86400,
              temporary: false,
            ),
          ],
          onCreateGuildInvite: (channelId, request) async {
            createdChannelId = channelId;
            createdRequest = request;
            return const DiscordGuildInvite(
              code: 'new123',
              channelId: 'channel-1',
              channelName: 'general',
              uses: 0,
              maxUses: 1,
              maxAgeSeconds: 86400,
              temporary: false,
            );
          },
          onDeleteGuildInvite: (code) async {
            deletedCode = code;
          },
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('서버 설정'));
    await tester.pumpAndSettle();
    expect(find.text('abc123'), findsOneWidget);

    await tester.tap(find.byTooltip('초대 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('invite-max-uses-field')),
      '1',
    );
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    expect(createdChannelId, 'channel-1');
    expect(createdRequest?.maxUses, 1);
    expect(find.text('new123'), findsOneWidget);

    await tester.tap(find.byTooltip('abc123 초대 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(deletedCode, 'abc123');
    expect(find.text('abc123'), findsNothing);
  });

  testWidgets('MANAGE_EVENTS 권한으로 예약 이벤트 목록·생성·수정·삭제를 요청한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    DiscordExternalEventRequest? createdRequest;
    String? updatedEventId;
    DiscordExternalEventRequest? updatedRequest;
    DiscordScheduledEventStatus? updatedStatus;
    String? deletedEventId;
    final existingEvent = DiscordScheduledEvent(
      id: 'event-1',
      guildId: 'guild-1',
      name: '기존 모임',
      scheduledStartTime: DateTime.utc(2030, 1, 1, 10),
      scheduledEndTime: DateTime.utc(2030, 1, 1, 11),
      status: DiscordScheduledEventStatus.scheduled,
      entityType: DiscordScheduledEventEntityType.external,
      location: '서울',
    );
    final state = DiscordWorkspaceState.fromCollections(
      guilds: [
        DiscordGuild(
          id: 'guild-1',
          name: '개발 서버',
          roles: [
            DiscordRole(
              id: 'guild-1',
              name: '@everyone',
              position: 0,
              permissions:
                  DiscordPermissions.viewChannel |
                  DiscordPermissions.manageEvents,
            ),
          ],
        ),
      ],
      channels: const [
        DiscordChannel(
          id: 'channel-1',
          guildId: 'guild-1',
          name: 'general',
          type: 0,
          position: 0,
        ),
      ],
      currentUser: const DiscordUser(id: 'user-1', username: 'alice'),
    );
    final peopleState = const DiscordPeopleState().payloadReceived({
      'op': 0,
      't': 'GUILD_CREATE',
      'd': {
        'id': 'guild-1',
        'members': [
          {
            'roles': [],
            'user': {'id': 'user-1', 'username': 'alice'},
          },
        ],
        'presences': [],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          peopleState: peopleState,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'channel-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLoadScheduledEvents: () async => [existingEvent],
          onCreateScheduledEvent: (request) async {
            createdRequest = request;
            return DiscordScheduledEvent(
              id: 'event-new',
              guildId: 'guild-1',
              name: request.name,
              scheduledStartTime: request.scheduledStartTime,
              scheduledEndTime: request.scheduledEndTime,
              status: DiscordScheduledEventStatus.scheduled,
              entityType: DiscordScheduledEventEntityType.external,
              location: request.location,
            );
          },
          onUpdateScheduledEvent: (eventId, request, {status}) async {
            updatedEventId = eventId;
            updatedRequest = request;
            updatedStatus = status;
            return DiscordScheduledEvent(
              id: eventId,
              guildId: 'guild-1',
              name: request.name,
              scheduledStartTime: request.scheduledStartTime,
              scheduledEndTime: request.scheduledEndTime,
              status: status ?? DiscordScheduledEventStatus.scheduled,
              entityType: DiscordScheduledEventEntityType.external,
              location: request.location,
            );
          },
          onDeleteScheduledEvent: (eventId) async {
            deletedEventId = eventId;
          },
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('서버 설정'));
    await tester.pumpAndSettle();
    expect(find.text('기존 모임'), findsOneWidget);

    await tester.tap(find.byTooltip('예약 이벤트 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('event-name-field')),
      '새 모임',
    );
    await tester.enterText(
      find.byKey(const ValueKey('event-location-field')),
      '부산',
    );
    await tester.enterText(
      find.byKey(const ValueKey('event-start-field')),
      '2030-02-01T10:00:00Z',
    );
    await tester.enterText(
      find.byKey(const ValueKey('event-end-field')),
      '2030-02-01T11:00:00Z',
    );
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(createdRequest?.name, '새 모임');
    expect(createdRequest?.location, '부산');
    expect(find.text('새 모임'), findsOneWidget);

    await tester.tap(find.byTooltip('기존 모임 이벤트 설정'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('event-name-field')),
      '수정된 모임',
    );
    await tester.tap(find.byKey(const ValueKey('event-status-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('진행 중').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(updatedEventId, 'event-1');
    expect(updatedRequest?.name, '수정된 모임');
    expect(updatedStatus, DiscordScheduledEventStatus.active);

    await tester.tap(find.byTooltip('수정된 모임 이벤트 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제').last);
    await tester.pumpAndSettle();

    expect(deletedEventId, 'event-1');
    expect(find.text('수정된 모임'), findsNothing);
  });

  testWidgets('forum channel의 post를 표시하고 새 post를 요청한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? selectedPostId;
    String? createdForumId;
    String? createdTitle;
    String? createdContent;
    List<String>? createdTagIds;
    final state = DiscordWorkspaceState.fromCollections(
      guilds: [
        DiscordGuild(
          id: 'guild-1',
          name: '개발 서버',
          roles: [
            DiscordRole(
              id: 'guild-1',
              name: '@everyone',
              position: 0,
              permissions:
                  DiscordPermissions.viewChannel |
                  DiscordPermissions.sendMessages,
            ),
          ],
        ),
      ],
      channels: const [
        DiscordChannel(
          id: 'forum-1',
          guildId: 'guild-1',
          name: '질문',
          type: 15,
          position: 0,
          topic: '질문 게시판',
          availableTags: [
            DiscordForumTag(id: 'tag-1', name: '도움', moderated: false),
          ],
        ),
        DiscordChannel(
          id: 'post-1',
          guildId: 'guild-1',
          name: '기존 질문',
          type: 11,
          position: 0,
          parentId: 'forum-1',
          appliedTagIds: ['tag-1'],
        ),
      ],
      currentUser: const DiscordUser(id: 'user-1', username: 'alice'),
    );
    final peopleState = const DiscordPeopleState().payloadReceived({
      'op': 0,
      't': 'GUILD_CREATE',
      'd': {
        'id': 'guild-1',
        'members': [
          {
            'roles': [],
            'user': {'id': 'user-1', 'username': 'alice'},
          },
        ],
        'presences': [],
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: state,
          peopleState: peopleState,
          selectedGuildId: 'guild-1',
          selectedChannelId: 'forum-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (channelId) {
            selectedPostId = channelId;
          },
          onCreateForumPost:
              (
                forumChannelId, {
                required title,
                required content,
                appliedTagIds = const [],
              }) async {
                createdForumId = forumChannelId;
                createdTitle = title;
                createdContent = content;
                createdTagIds = appliedTagIds;
              },
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('질문 게시판'), findsOneWidget);
    expect(find.text('기존 질문'), findsNWidgets(2));
    await tester.tap(find.text('기존 질문').last);
    expect(selectedPostId, 'post-1');

    await tester.tap(find.byTooltip('포럼 글 작성'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('forum-title-field')),
      '새 질문',
    );
    await tester.enterText(
      find.byKey(const ValueKey('forum-content-field')),
      '질문 본문',
    );
    await tester.tap(find.byKey(const ValueKey('forum-tag-tag-1')));
    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();

    expect(createdForumId, 'forum-1');
    expect(createdTitle, '새 질문');
    expect(createdContent, '질문 본문');
    expect(createdTagIds, ['tag-1']);
  });
}
