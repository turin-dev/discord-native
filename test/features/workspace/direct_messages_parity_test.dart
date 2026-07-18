import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/messages/domain/discord_message_search_state.dart';
import 'package:discord_native/features/system/domain/desktop_settings.dart';
import 'package:discord_native/features/system/presentation/desktop_theme.dart';
import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/discord_workspace_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('현대 READY group DM을 Discord 전용 shell로 렌더링한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final payload = _readyPayload();
    final workspace = const DiscordWorkspaceState().payloadReceived(payload);
    final people = const DiscordPeopleState().payloadReceived(payload);

    await tester.pumpWidget(
      MaterialApp(
        theme: createDesktopTheme(
          const DesktopSettings.defaults(),
          Brightness.dark,
        ),
        home: DiscordWorkspacePage(
          state: workspace,
          peopleState: people,
          messageState: DiscordMessageState.loaded('group-1', const []),
          selectedGuildId: discordDirectMessagesGuildId,
          selectedChannelId: 'group-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onSendMessage: (_) async {},
          onOpenDirectMessage: (_) async {},
          onLogout: () {},
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('direct-messages-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('direct-messages-friends')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('direct-message-channel-dm-1')),
      findsOneWidget,
    );
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('알 수 없는 사용자'), findsNothing);
    expect(find.byKey(const ValueKey('direct-message-header')), findsOneWidget);
    expect(find.text('프로젝트방'), findsWidgets);
    expect(find.text('멤버 — 3'), findsOneWidget);
    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('message-composer-field')),
    );
    expect(composer.decoration?.hintText, '프로젝트방에 메시지 보내기');
  });

  testWidgets('친구 바로가기는 실제 DM 홈을 연다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final payload = _readyPayload();

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: const DiscordWorkspaceState().payloadReceived(payload),
          peopleState: const DiscordPeopleState().payloadReceived(payload),
          selectedGuildId: discordDirectMessagesGuildId,
          selectedChannelId: 'group-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onOpenDirectMessage: (_) async {},
          onLogout: () {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('direct-messages-friends')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('direct-messages-home')), findsOneWidget);
    expect(find.text('모든 친구'), findsOneWidget);
    expect(find.text('Bob'), findsWidgets);
  });

  testWidgets('1대1 DM은 그룹 멤버 패널 없이 대화 폭을 사용한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final payload = _readyPayload();

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: const DiscordWorkspaceState().payloadReceived(payload),
          peopleState: const DiscordPeopleState().payloadReceived(payload),
          selectedGuildId: discordDirectMessagesGuildId,
          selectedChannelId: 'dm-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('멤버 — 2'), findsNothing);
    expect(find.byKey(const ValueKey('direct-message-header')), findsOneWidget);
  });

  testWidgets('DM header 검색은 현재 대화만 검색한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? searchedQuery;
    bool? searchedCurrentChannelOnly;

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: const DiscordWorkspaceState().payloadReceived(_readyPayload()),
          peopleState: const DiscordPeopleState().payloadReceived(
            _readyPayload(),
          ),
          selectedGuildId: discordDirectMessagesGuildId,
          selectedChannelId: 'group-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onSearchMessages: (query, currentChannelOnly) async {
            searchedQuery = query;
            searchedCurrentChannelOnly = currentChannelOnly;
          },
          onLogout: () {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('direct-message-header-search')),
      ' 회의 ',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(searchedQuery, '회의');
    expect(searchedCurrentChannelOnly, isTrue);
  });

  testWidgets('활성 DM 검색은 group member panel을 결과로 교체한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final result = DiscordMessage(
      id: 'message-search',
      channelId: 'group-1',
      content: '회의 검색 결과',
      authorId: 'user-2',
      authorName: 'bob',
      timestamp: DateTime.utc(2026, 7, 18, 10),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DiscordWorkspacePage(
          state: const DiscordWorkspaceState().payloadReceived(_readyPayload()),
          peopleState: const DiscordPeopleState().payloadReceived(
            _readyPayload(),
          ),
          searchState: DiscordMessageSearchState.loaded(
            query: '회의',
            totalResults: 1,
            messages: [result],
            currentChannelOnly: true,
          ),
          selectedGuildId: discordDirectMessagesGuildId,
          selectedChannelId: 'group-1',
          connectionLabel: '연결됨',
          onSelectGuild: (_) {},
          onSelectChannel: (_) {},
          onSearchMessages: (_, _) async {},
          onClearSearch: () {},
          onLogout: () {},
        ),
      ),
    );

    expect(find.text('회의 검색 결과'), findsOneWidget);
    expect(find.text('멤버 — 3'), findsNothing);
    expect(find.byKey(const ValueKey('current-channel-only')), findsNothing);
  });
}

Map<String, Object?> _readyPayload() {
  return {
    'op': 0,
    't': 'READY',
    'd': {
      'user': {'id': 'user-1', 'username': 'alice', 'global_name': 'Alice'},
      'guilds': [],
      'users': [
        {'id': 'user-2', 'username': 'bob', 'global_name': 'Bob'},
        {'id': 'user-3', 'username': 'carol', 'global_name': 'Carol'},
      ],
      'relationships': [
        {'id': 'user-2', 'type': 1},
      ],
      'private_channels': [
        {
          'id': 'dm-1',
          'type': 1,
          'recipient_ids': ['user-2'],
        },
        {
          'id': 'group-1',
          'type': 3,
          'name': '프로젝트방',
          'recipient_ids': ['user-2', 'user-3'],
        },
      ],
      'presences': [
        {
          'user': {'id': 'user-2'},
          'status': 'online',
          'activities': [],
        },
      ],
    },
  };
}
