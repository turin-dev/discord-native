import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/discord_workspace_page.dart';
import 'package:discord_native/features/workspace/presentation/workspace_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('title bar Inbox를 연다', (tester) async {
    await _setDesktopSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: _workspace(state: _state(), onSelectChannel: (_) {}),
      ),
    );

    await tester.tap(find.widgetWithIcon(IconButton, Icons.inbox_outlined));
    await tester.pumpAndSettle();
    expect(find.text('받은 편지함'), findsOneWidget);
  });

  testWidgets('방문한 채널을 뒤로와 앞으로 탐색한다', (tester) async {
    await _setDesktopSurface(tester);
    var selectedChannelId = 'channel-1';
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => _workspace(
            state: _state(),
            selectedChannelId: selectedChannelId,
            onSelectChannel: (channelId) {
              setState(() => selectedChannelId = channelId);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('random'));
    await tester.pump();
    expect(selectedChannelId, 'channel-2');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back_ios_new));
    await tester.pump();
    expect(selectedChannelId, 'channel-1');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_forward_ios));
    await tester.pump();
    expect(selectedChannelId, 'channel-2');
  });

  testWidgets('채널 목록 폭을 drag하고 저장한다', (tester) async {
    await _setDesktopSurface(tester);
    double? persistedWidth;
    await tester.pumpWidget(
      MaterialApp(
        home: _workspace(
          state: _state(),
          onSelectChannel: (_) {},
          onChannelSidebarWidthChanged: (width) => persistedWidth = width,
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('channel-sidebar-resize-handle')),
      const Offset(80, 0),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(ChannelSidebar)).width, 320);
    expect(persistedWidth, 320);
  });

  testWidgets('고정한 채널을 상단에 표시하고 고정 해제를 요청한다', (tester) async {
    await _setDesktopSurface(tester);
    String? toggledChannelId;
    await tester.pumpWidget(
      MaterialApp(
        home: _workspace(
          state: _state(),
          onSelectChannel: (_) {},
          pinnedChannelIds: const {'channel-2'},
          onToggleChannelPinned: (channelId) {
            toggledChannelId = channelId;
          },
        ),
      ),
    );

    expect(find.text('고정됨'), findsOneWidget);
    await tester.tap(find.byTooltip('random 고정 해제'));
    expect(toggledChannelId, 'channel-2');
  });

  testWidgets('private client API 실패를 로컬 fallback 경고로 표시한다', (tester) async {
    await _setDesktopSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: _workspace(
          state: _state(),
          onSelectChannel: (_) {},
          clientApiWarning: '읽음 상태는 로컬에는 저장됩니다.',
        ),
      ),
    );

    expect(find.byKey(const ValueKey('client-api-warning')), findsOneWidget);
    expect(find.text('읽음 상태는 로컬에는 저장됩니다.'), findsOneWidget);
  });

  testWidgets('투표를 렌더링하고 composer에서 새 투표를 만든다', (tester) async {
    await _setDesktopSurface(tester);
    DiscordPollDraft? submitted;
    int? selectedAnswerId;
    await tester.pumpWidget(
      MaterialApp(
        home: _workspace(
          state: _state(),
          messageState: _pollMessageState(),
          onSelectChannel: (_) {},
          onSendPoll: (draft) async => submitted = draft,
          onVotePoll: (message, answerId) async {
            selectedAnswerId = answerId;
          },
        ),
      ),
    );

    expect(find.text('오늘 배포할까요?'), findsOneWidget);
    expect(find.text('3표 · 단일 선택 · 진행 중'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('poll-answer-2')));
    await tester.pump();
    expect(selectedAnswerId, 2);
    await tester.tap(find.byTooltip('파일 첨부'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('투표 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('poll-question-field')),
      '점심 메뉴는?',
    );
    await tester.enterText(find.byKey(const ValueKey('poll-answer-0')), '김치찌개');
    await tester.enterText(find.byKey(const ValueKey('poll-answer-1')), '돈가스');
    await tester.tap(find.text('투표 게시'));
    await tester.pumpAndSettle();
    expect(submitted?.question, '점심 메뉴는?');
    expect(submitted?.answers, ['김치찌개', '돈가스']);
  });
}

Future<void> _setDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

DiscordWorkspacePage _workspace({
  required DiscordWorkspaceState state,
  required ValueChanged<String> onSelectChannel,
  String? selectedChannelId = 'channel-1',
  DiscordMessageState messageState = const DiscordMessageState(),
  Future<void> Function(DiscordPollDraft draft)? onSendPoll,
  PollVoteCallback? onVotePoll,
  ValueChanged<double>? onChannelSidebarWidthChanged,
  Set<String> pinnedChannelIds = const {},
  ValueChanged<String>? onToggleChannelPinned,
  String? clientApiWarning,
}) {
  return DiscordWorkspacePage(
    state: state,
    messageState: messageState,
    selectedGuildId: 'guild-1',
    selectedChannelId: selectedChannelId,
    connectionLabel: '연결됨',
    onSelectGuild: (_) {},
    onSelectChannel: onSelectChannel,
    onSendPoll: onSendPoll,
    onVotePoll: onVotePoll,
    onChannelSidebarWidthChanged: onChannelSidebarWidthChanged,
    pinnedChannelIds: pinnedChannelIds,
    onToggleChannelPinned: onToggleChannelPinned,
    clientApiWarning: clientApiWarning,
    onLogout: () {},
  );
}

DiscordWorkspaceState _state() => DiscordWorkspaceState.fromCollections(
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
  currentUser: const DiscordUser(id: 'user-1', username: 'alice'),
);

DiscordMessageState _pollMessageState() =>
    DiscordMessageState.loaded('channel-1', [
      DiscordMessage(
        id: 'message-poll',
        channelId: 'channel-1',
        content: '',
        authorId: 'user-1',
        authorName: 'alice',
        timestamp: DateTime.utc(2026, 7, 16, 10),
        poll: const DiscordPoll(
          question: '오늘 배포할까요?',
          answers: [
            DiscordPollAnswer(id: 1, text: '예', voteCount: 2, meVoted: true),
            DiscordPollAnswer(id: 2, text: '아니요', voteCount: 1, meVoted: false),
          ],
          allowMultiselect: false,
          finalized: false,
        ),
      ),
    ]);
