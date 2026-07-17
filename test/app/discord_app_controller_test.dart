import 'dart:async';

import 'package:discord_native/app/discord_app_controller.dart';
import 'package:discord_native/app/typing_expiry_scheduler.dart';
import 'package:discord_native/core/auth/secure_token_repository.dart';
import 'package:discord_native/core/gateway/discord_gateway_client.dart';
import 'package:discord_native/core/gateway/gateway_session_state.dart';
import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/messages/data/discord_message_repository.dart';
import 'package:discord_native/features/messages/data/attachment_download_service.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/data/discord_direct_message_repository.dart';
import 'package:discord_native/features/workspace/data/discord_channel_management_repository.dart';
import 'package:discord_native/features/workspace/data/discord_client_sync_repository.dart';
import 'package:discord_native/features/workspace/data/discord_role_repository.dart';
import 'package:discord_native/features/workspace/data/discord_invite_repository.dart';
import 'package:discord_native/features/workspace/data/discord_scheduled_event_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_scheduled_event.dart';
import 'package:discord_native/features/workspace/data/discord_thread_repository.dart';
import 'package:discord_native/features/workspace/data/discord_relationship_repository.dart';
import 'package:discord_native/features/workspace/data/read_state_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_people_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordAppController', () {
    late _FakeTokenRepository tokens;
    late _FakeGatewayConnection gateway;
    late DiscordAppController controller;

    setUp(() {
      tokens = _FakeTokenRepository();
      gateway = _FakeGatewayConnection();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
      );
    });

    tearDown(() async {
      await controller.dispose();
      await gateway.disposeStreams();
    });

    test('저장 토큰이 없으면 로그인 화면 상태가 된다', () async {
      await controller.initialize();

      expect(controller.state.phase, DiscordAppPhase.signedOut);
    });

    test('저장 토큰으로 자동 연결하고 READY 이후 연결됨 상태가 된다', () async {
      tokens = _FakeTokenRepository('saved.token');
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
      );

      await controller.initialize();
      gateway.emitState(
        const GatewaySessionState(
          phase: GatewayPhase.ready,
          sessionId: 'session-1',
          resumeGatewayUrl: 'wss://resume.discord.gg',
        ),
      );
      await pumpEventQueue();

      expect(gateway.connectedToken, 'saved.token');
      expect(controller.state.phase, DiscordAppPhase.connected);
    });

    test('guild event 수신 시 첫 guild와 channel을 자동 선택한다', () async {
      await controller.initialize();
      await controller.connect('manual.token');

      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      expect(controller.state.selectedGuildId, 'guild-1');
      expect(controller.state.selectedChannelId, 'channel-1');
      expect(tokens.savedToken, 'manual.token');
    });

    test('로그아웃은 저장 토큰과 연결 상태를 정리한다', () async {
      await controller.initialize();
      await controller.connect('manual.token');

      await controller.logout();

      expect(tokens.savedToken, isNull);
      expect(gateway.disconnectCount, 1);
      expect(controller.state.phase, DiscordAppPhase.signedOut);
    });

    test('채널 선택 시 히스토리를 불러오고 메시지를 전송한다', () async {
      final messages = _FakeMessageRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
      );
      await controller.initialize();
      await controller.connect('manual.token');

      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      expect(controller.state.messageState.messages.single.content, '기존 메시지');

      await controller.sendMessage('새 메시지');

      expect(messages.sentContent, '새 메시지');
      expect(controller.state.messageState.messages.last.content, '새 메시지');
      expect(
        controller.state.readStates['channel-1']?.lastReadMessageId,
        'message-2',
      );
    });

    test('선택한 채널에 sticker를 전송하고 메시지 상태에 추가한다', () async {
      final messages = _FakeMessageRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      await controller.sendSticker('sticker-1');

      expect(messages.sentStickerIds, ['sticker-1']);
      expect(
        controller.state.messageState.messages.last.stickers.single.id,
        'sticker-1',
      );
      expect(
        controller.state.readStates['channel-1']?.lastReadMessageId,
        'message-sticker',
      );
    });

    test('poll 답변 선택을 private client API에 위임하고 메시지에 반영한다', () async {
      final pollMessage = DiscordMessage(
        id: 'message-poll',
        channelId: 'channel-1',
        content: '',
        authorId: 'user-1',
        authorName: 'alice',
        timestamp: DateTime.utc(2026, 7, 16, 10),
        poll: const DiscordPoll(
          question: '점심 메뉴는?',
          answers: [
            DiscordPollAnswer(id: 1, text: '한식', voteCount: 1, meVoted: true),
            DiscordPollAnswer(id: 2, text: '양식', voteCount: 0, meVoted: false),
          ],
          allowMultiselect: false,
          finalized: false,
        ),
      );
      final messages = _FakeMessageRepository(initialMessages: [pollMessage]);
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      await controller.votePoll(pollMessage, 2);

      expect(messages.votedMessageId, 'message-poll');
      expect(messages.votedAnswerIds, {2});
      final answers =
          controller.state.messageState.messages.single.poll!.answers;
      expect(answers.first.meVoted, isFalse);
      expect(answers.last.meVoted, isTrue);
    });

    test('read ACK가 지원되지 않아도 로컬 읽음 상태를 보존하고 경고한다', () async {
      final messages = _FakeMessageRepository();
      final sync = _FakeClientSyncRepository(
        error: const DiscordHttpException(statusCode: 404, message: 'Unknown'),
      );
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
        clientSyncRepositoryFactory: (_) => sync,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      expect(
        controller.state.readStates['channel-1']?.lastReadMessageId,
        'message-1',
      );
      expect(sync.acknowledgedMessageIds, ['message-1']);
      expect(controller.state.clientApiWarning, contains('로컬에는 저장'));
    });

    test('guild 선택 시 해당 guild의 첫 채널을 선택한다', () async {
      final messages = _FakeMessageRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-2',
          'name': '게임 서버',
          'channels': [
            {
              'id': 'channel-2',
              'guild_id': 'guild-2',
              'name': 'party',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      controller.selectGuild('guild-2');
      await pumpEventQueue();

      expect(controller.state.selectedGuildId, 'guild-2');
      expect(controller.state.selectedChannelId, 'channel-2');
    });

    test('답장 전송과 reaction toggle을 repository에 위임한다', () async {
      final messages = _FakeMessageRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      await controller.sendReply('답장', 'message-1');
      await controller.toggleReaction(
        controller.state.messageState.messages.first,
        const DiscordReaction(emojiName: '👍', count: 1, me: false),
      );
      await controller.toggleReaction(
        controller.state.messageState.messages.first,
        const DiscordReaction(emojiName: '🔥', count: 1, me: true),
      );

      expect(messages.repliedToMessageId, 'message-1');
      expect(messages.addedReaction, '👍');
      expect(messages.removedReaction, '🔥');
    });

    test('선택한 채널에 첨부 파일을 전송하고 메시지 상태에 추가한다', () async {
      final messages = _FakeMessageRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();
      const files = [
        DiscordUploadFile(
          filename: 'image.png',
          bytes: [1, 2, 3],
          contentType: 'image/png',
        ),
      ];

      await controller.sendAttachments(
        '설명',
        files,
        replyToMessageId: 'message-1',
      );

      expect(messages.sentAttachments, files);
      expect(messages.attachmentReplyTargetId, 'message-1');
      expect(controller.state.messageState.messages.last.content, '설명');
      expect(
        controller.state.messageState.messages.last.attachments.single.filename,
        'image.png',
      );
    });

    test('첨부 다운로드를 download service에 위임한다', () async {
      final downloads = _FakeAttachmentDownloadService();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        attachmentDownloadService: downloads,
      );
      const attachment = DiscordAttachment(
        id: 'attachment-1',
        filename: 'image.png',
        url: 'https://cdn.discordapp.com/image.png',
        proxyUrl: 'https://media.discordapp.net/image.png',
        size: 1024,
      );

      final path = await controller.downloadAttachment(attachment);

      expect(downloads.downloadedAttachmentId, 'attachment-1');
      expect(path, r'C:\Downloads\image.png');
    });

    test('thread 목록·생성·참여·보관 흐름을 상태에 반영한다', () async {
      final messages = _FakeMessageRepository();
      final threads = _FakeThreadRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
        threadRepositoryFactory: (_) => threads,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      await controller.refreshThreads('channel-1');
      await controller.createThread('channel-1', '새 스레드');
      await controller.joinThread('thread-new');
      await controller.setThreadArchived('thread-new', true);
      await controller.startThreadFromMessage('message-1', '원문 토론');

      expect(threads.listedParentChannelId, 'channel-1');
      expect(
        controller.state.workspace.channels.any(
          (channel) => channel.id == 'thread-archived',
        ),
        isTrue,
      );
      expect(threads.createdName, '새 스레드');
      expect(threads.joinedThreadId, 'thread-new');
      expect(threads.archivedThreadId, 'thread-new');
      expect(
        controller.state.workspace.channels
            .singleWhere((channel) => channel.id == 'thread-new')
            .isArchived,
        isTrue,
      );
      expect(threads.startedFromMessageId, 'message-1');
      expect(controller.state.selectedChannelId, 'thread-message');
    });

    test('forum channel을 선택하고 새 post를 workspace에 반영한다', () async {
      final threads = _FakeThreadRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        threadRepositoryFactory: (_) => threads,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'forum-1',
              'guild_id': 'guild-1',
              'name': '질문',
              'type': 15,
              'position': 0,
              'available_tags': [
                {'id': 'tag-1', 'name': '도움', 'moderated': false},
              ],
            },
          ],
        },
      });
      await pumpEventQueue();

      await controller.createForumPost(
        'forum-1',
        title: '질문 제목',
        content: '질문 본문',
        appliedTagIds: const ['tag-1'],
      );

      expect(threads.forumChannelId, 'forum-1');
      expect(threads.forumTitle, '질문 제목');
      expect(threads.forumContent, '질문 본문');
      expect(threads.forumTagIds, ['tag-1']);
      expect(controller.state.selectedChannelId, 'post-new');
      expect(
        controller.state.workspace.channelById('post-new')?.parentId,
        'forum-1',
      );
    });

    test('guild channel 생성·수정·삭제를 workspace에 반영한다', () async {
      final messages = _FakeMessageRepository();
      final channels = _FakeChannelManagementRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
        channelManagementRepositoryFactory: (_) => channels,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      await controller.createGuildChannel(
        const DiscordCreateChannelRequest(
          name: '새 채널',
          type: DiscordGuildChannelType.text,
        ),
      );
      await controller.updateGuildChannel(
        'channel-new',
        const DiscordUpdateChannelRequest(name: '새 이름'),
      );
      await controller.deleteGuildChannel('channel-new');

      expect(channels.createdGuildId, 'guild-1');
      expect(channels.createdRequest?.name, '새 채널');
      expect(channels.updatedChannelId, 'channel-new');
      expect(channels.deletedChannelId, 'channel-new');
      expect(
        controller.state.workspace.channels.any(
          (channel) => channel.id == 'channel-new',
        ),
        isFalse,
      );
      expect(controller.state.selectedChannelId, 'channel-1');
      expect(controller.state.guildErrorMessage, isNull);
    });

    test('guild role 생성·수정·순서 변경·삭제를 workspace에 반영한다', () async {
      final roles = _FakeRoleRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        roleRepositoryFactory: (_) => roles,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'roles': [
            {
              'id': 'guild-1',
              'name': '@everyone',
              'position': 0,
              'permissions': '1024',
              'color': 0,
            },
          ],
          'channels': [],
        },
      });
      await pumpEventQueue();

      await controller.createGuildRole(
        DiscordRoleRequest(name: '운영진', permissions: BigInt.from(8192)),
      );
      await controller.updateGuildRole(
        'role-new',
        DiscordRoleRequest(name: '관리자', permissions: BigInt.from(8200)),
      );
      await controller.updateGuildRolePositions(const {'role-new': 2});
      await controller.deleteGuildRole('role-new');

      expect(roles.createdGuildId, 'guild-1');
      expect(roles.updatedRoleId, 'role-new');
      expect(roles.updatedPositions, const {'role-new': 2});
      expect(roles.deletedRoleId, 'role-new');
      expect(controller.state.workspace.guilds.single.roles, hasLength(1));
      expect(controller.state.guildErrorMessage, isNull);
    });

    test('guild invite 목록·생성·삭제를 repository에 위임한다', () async {
      final invites = _FakeInviteRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        inviteRepositoryFactory: (_) => invites,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      final loaded = await controller.loadGuildInvites();
      final created = await controller.createGuildInvite(
        'channel-1',
        const DiscordInviteRequest(maxUses: 1),
      );
      await controller.deleteGuildInvite('new123');

      expect(invites.loadedGuildId, 'guild-1');
      expect(invites.createdChannelId, 'channel-1');
      expect(invites.deletedCode, 'new123');
      expect(loaded.single.code, 'abc123');
      expect(created?.code, 'new123');
      expect(controller.state.guildErrorMessage, isNull);
    });

    test('scheduled event 목록·생성·수정·삭제를 workspace에 반영한다', () async {
      final events = _FakeScheduledEventRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        scheduledEventRepositoryFactory: (_) => events,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [],
          'guild_scheduled_events': [],
        },
      });
      await pumpEventQueue();
      final request = DiscordExternalEventRequest(
        name: '정기 모임',
        location: '서울',
        scheduledStartTime: DateTime.utc(2026, 7, 20, 10),
        scheduledEndTime: DateTime.utc(2026, 7, 20, 12),
      );

      await controller.loadScheduledEvents();
      await controller.createScheduledEvent(request);
      await controller.updateScheduledEvent(
        'event-new',
        request,
        status: DiscordScheduledEventStatus.active,
      );
      await controller.deleteScheduledEvent('event-new');

      expect(events.loadedGuildId, 'guild-1');
      expect(events.createdRequest?.name, '정기 모임');
      expect(events.updatedEventId, 'event-new');
      expect(events.updatedStatus, DiscordScheduledEventStatus.active);
      expect(events.deletedEventId, 'event-new');
      expect(
        controller.state.workspace.scheduledEvents.single.id,
        'event-existing',
      );
      expect(controller.state.guildErrorMessage, isNull);
    });

    test('guild 메시지 검색과 결과 주변 컨텍스트를 로드한다', () async {
      final messages = _FakeMessageRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      await controller.searchMessages('설계', currentChannelOnly: true);
      final result = controller.state.searchState.messages.single;
      await controller.selectSearchResult(result);

      expect(messages.searchQuery, '설계');
      expect(messages.searchChannelId, 'channel-1');
      expect(controller.state.searchState.totalResults, 1);
      expect(
        controller.state.workspace.channels.any(
          (channel) => channel.id == 'thread-search',
        ),
        isTrue,
      );
      expect(messages.aroundMessageId, 'message-search');
      expect(controller.state.selectedChannelId, 'channel-1');
      expect(
        controller.state.messageState.messages.single.id,
        'message-search',
      );

      controller.clearSearch();

      expect(controller.state.searchState.query, isEmpty);
      expect(controller.state.searchState.messages, isEmpty);
    });

    test('로컬 read state를 복원하고 unread를 증가·초기화한다', () async {
      final messages = _FakeMessageRepository();
      final reads = _FakeReadStateRepository({
        'channel-2': DiscordReadState(
          channelId: 'channel-2',
          lastReadMessageId: 'message-old',
          unreadCount: 2,
          updatedAt: DateTime.utc(2026, 7, 16, 9),
        ),
      });
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
        readStateRepository: reads,
        now: () => DateTime.utc(2026, 7, 16, 12),
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
            {
              'id': 'channel-2',
              'guild_id': 'guild-1',
              'name': 'random',
              'type': 0,
              'position': 1,
            },
          ],
        },
      });
      await pumpEventQueue();

      gateway.emitEvent({
        'op': 0,
        't': 'MESSAGE_CREATE',
        'd': {
          'id': 'message-unread',
          'channel_id': 'channel-2',
          'content': '새 메시지',
          'timestamp': '2026-07-16T12:00:00.000Z',
          'author': {'id': 'user-2', 'username': 'bob'},
        },
      });
      await pumpEventQueue();

      expect(controller.state.readStates['channel-2']?.unreadCount, 3);

      controller.selectChannel('channel-2');
      await pumpEventQueue();

      expect(controller.state.readStates['channel-2']?.unreadCount, 0);
      expect(
        controller.state.readStates['channel-2']?.lastReadMessageId,
        'message-1',
      );

      gateway.emitEvent({
        'op': 0,
        't': 'MESSAGE_CREATE',
        'd': {
          'id': 'message-selected',
          'channel_id': 'channel-2',
          'content': '보고 있는 메시지',
          'timestamp': '2026-07-16T12:01:00.000Z',
          'author': {'id': 'user-2', 'username': 'bob'},
        },
      });
      await pumpEventQueue();

      expect(
        controller.state.readStates['channel-2']?.lastReadMessageId,
        'message-selected',
      );
      expect(controller.state.readStates['channel-2']?.unreadCount, 0);
      expect(reads.savedStates, isNotEmpty);

      await controller.logout();

      expect(reads.states, isEmpty);
    });

    test('READY와 MESSAGE_ACK를 로컬 read state와 양방향 조정한다', () async {
      final reads = _FakeReadStateRepository({
        'channel-1': DiscordReadState(
          channelId: 'channel-1',
          lastReadMessageId: '100',
          unreadCount: 3,
          updatedAt: DateTime.utc(2026, 7, 16, 9),
        ),
        'channel-2': DiscordReadState(
          channelId: 'channel-2',
          lastReadMessageId: '300',
          unreadCount: 0,
          updatedAt: DateTime.utc(2026, 7, 16, 9),
        ),
      });
      final sync = _FakeClientSyncRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        readStateRepository: reads,
        clientSyncRepositoryFactory: (_) => sync,
        now: () => DateTime.utc(2026, 7, 16, 12),
      );
      await controller.initialize();
      await controller.connect('manual.token');

      gateway.emitEvent({
        'op': 0,
        't': 'READY',
        'd': {
          'user': {'id': 'user-me', 'username': 'me'},
          'guilds': [
            {'id': 'guild-1', 'name': '개발 서버'},
          ],
          'read_state': {
            'entries': [
              {
                'id': 'channel-1',
                'read_state_type': 0,
                'last_message_id': '200',
                'mention_count': 0,
              },
              {
                'id': 'channel-2',
                'read_state_type': 0,
                'last_message_id': '200',
                'mention_count': 0,
              },
            ],
            'version': 9,
            'partial': false,
          },
        },
      });
      await pumpEventQueue();

      expect(
        controller.state.readStates['channel-1']?.lastReadMessageId,
        '200',
      );
      expect(controller.state.readStates['channel-1']?.unreadCount, 0);
      expect(
        controller.state.readStates['channel-2']?.lastReadMessageId,
        '300',
      );
      expect(sync.acknowledgedMessageIds, ['300']);

      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
              'last_message_id': '250',
            },
            {
              'id': 'channel-2',
              'guild_id': 'guild-1',
              'name': 'random',
              'type': 0,
              'position': 1,
              'last_message_id': '350',
            },
          ],
        },
      });
      await pumpEventQueue();

      expect(
        controller.state.readStates['channel-1']?.lastReadMessageId,
        '250',
      );
      expect(controller.state.readStates['channel-2']?.unreadCount, 1);
      expect(sync.acknowledgedMessageIds, ['300', '250']);

      gateway.emitEvent({
        'op': 0,
        't': 'MESSAGE_ACK',
        'd': {
          'channel_id': 'channel-1',
          'message_id': '150',
          'manual': true,
          'version': 10,
        },
      });
      await pumpEventQueue();

      expect(
        controller.state.readStates['channel-1']?.lastReadMessageId,
        '150',
      );
      expect(controller.state.readStates['channel-1']?.unreadCount, 1);
      expect(reads.savedStates.last.lastReadMessageId, '150');
    });

    test('메시지 편집·고정·삭제를 repository와 상태에 반영한다', () async {
      final messages = _FakeMessageRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();
      final original = controller.state.messageState.messages.single;

      await controller.editMessage(original, '수정됨');
      final edited = controller.state.messageState.messages.single;
      await controller.togglePinned(edited);
      final pinned = controller.state.messageState.messages.single;
      await controller.deleteMessage(pinned);

      expect(messages.editedContent, '수정됨');
      expect(messages.pinnedValue, isTrue);
      expect(messages.deletedMessageId, 'message-1');
      expect(controller.state.messageState.messages, isEmpty);
    });

    test('과거 메시지를 earliest message before cursor로 병합한다', () async {
      final initial = List.generate(
        50,
        (index) => DiscordMessage(
          id: 'message-${index + 50}',
          channelId: 'channel-1',
          content: '현재 ${index + 50}',
          authorId: 'user-1',
          authorName: 'alice',
          timestamp: DateTime.utc(2026, 7, 16, 10, index),
        ),
      );
      final messages = _FakeMessageRepository(
        initialMessages: initial,
        olderMessages: [
          DiscordMessage(
            id: 'message-1',
            channelId: 'channel-1',
            content: '가장 오래된 메시지',
            authorId: 'user-2',
            authorName: 'bob',
            timestamp: DateTime.utc(2026, 7, 16, 9),
          ),
        ],
      );
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      await pumpEventQueue();

      await controller.loadOlderMessages();

      expect(messages.beforeMessageId, 'message-50');
      expect(controller.state.messageState.messages.first.id, 'message-1');
      expect(controller.state.messageState.messages.length, 51);
      expect(controller.state.messageState.hasMore, isFalse);
    });

    test('typing event를 만료시키고 REST 전송을 8초 동안 throttle한다', () async {
      var now = DateTime.utc(2026, 7, 16, 10);
      final scheduler = _FakeTypingExpiryScheduler();
      final messages = _FakeMessageRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
        typingExpiryScheduler: scheduler,
        now: () => now,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'READY',
        'd': {
          'user': {'id': 'user-1', 'username': 'alice'},
          'guilds': [],
        },
      });
      gateway.emitEvent({
        'op': 0,
        't': 'GUILD_CREATE',
        'd': {
          'id': 'guild-1',
          'name': '개발 서버',
          'channels': [
            {
              'id': 'channel-1',
              'guild_id': 'guild-1',
              'name': 'general',
              'type': 0,
              'position': 0,
            },
          ],
        },
      });
      gateway.emitEvent({
        'op': 0,
        't': 'TYPING_START',
        'd': {
          'channel_id': 'channel-1',
          'guild_id': 'guild-1',
          'user_id': 'user-2',
          'timestamp': 1784196000,
          'member': {
            'nick': '밥',
            'user': {'id': 'user-2', 'username': 'bob'},
          },
        },
      });
      await pumpEventQueue();

      expect(
        controller.state.typingState
            .usersForChannel('channel-1')
            .single
            .displayName,
        '밥',
      );
      expect(scheduler.duration, const Duration(seconds: 10));

      await controller.triggerTyping();
      await controller.triggerTyping();
      now = now.add(const Duration(seconds: 8));
      await controller.triggerTyping();

      expect(messages.typingCount, 2);
      scheduler.expire();
      expect(
        controller.state.typingState.usersForChannel('channel-1'),
        isEmpty,
      );
    });

    test('READY의 DM과 친구 상태를 구성하고 첫 DM 히스토리를 연다', () async {
      final messages = _FakeMessageRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
      );
      await controller.initialize();
      await controller.connect('manual.token');

      gateway.emitEvent({
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
          ],
          'presences': [
            {
              'user': {'id': 'user-2'},
              'status': 'online',
              'activities': [],
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
      await pumpEventQueue();

      expect(controller.state.selectedGuildId, discordDirectMessagesGuildId);
      expect(controller.state.selectedChannelId, 'dm-1');
      expect(messages.fetchedChannelId, 'dm-1');
      expect(controller.state.peopleState.friends.single.displayName, '밥');
      expect(
        controller.state.peopleState.friends.single.status,
        DiscordPresenceStatus.online,
      );
    });

    test('친구 요청·수락·차단·삭제를 repository와 people state에 반영한다', () async {
      final relationships = _FakeRelationshipRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        relationshipRepositoryFactory: (_) => relationships,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'READY',
        'd': {
          'user': {'id': 'user-1', 'username': 'alice'},
          'guilds': [],
          'private_channels': [],
          'presences': [],
          'relationships': [
            {
              'id': 'user-2',
              'type': 3,
              'user': {'id': 'user-2', 'username': 'bob'},
            },
          ],
        },
      });
      await pumpEventQueue();
      final incoming = controller.state.peopleState.incomingRequests.single;

      await controller.sendFriendRequest(' new.friend ');
      await controller.acceptFriendRequest(incoming);
      final friend = controller.state.peopleState.friends.single;
      await controller.blockRelationship(friend);
      final blocked = controller.state.peopleState.blocked.single;
      await controller.removeRelationship(blocked);

      expect(relationships.requestedUsername, 'new.friend');
      expect(relationships.acceptedUserId, 'user-2');
      expect(relationships.blockedUserId, 'user-2');
      expect(relationships.removedUserId, 'user-2');
      expect(controller.state.peopleState.blocked, isEmpty);
    });

    test('친구의 DM channel을 생성하고 선택해 메시지를 불러온다', () async {
      final directMessages = _FakeDirectMessageRepository();
      final messages = _FakeMessageRepository();
      controller = DiscordAppController(
        tokenRepository: tokens,
        gateway: gateway,
        messageRepositoryFactory: (_) => messages,
        directMessageRepositoryFactory: (_) => directMessages,
      );
      await controller.initialize();
      await controller.connect('manual.token');
      gateway.emitEvent({
        'op': 0,
        't': 'READY',
        'd': {
          'user': {'id': 'user-1', 'username': 'alice'},
          'guilds': [],
          'private_channels': [],
          'presences': [],
          'relationships': [
            {
              'id': 'user-2',
              'type': 1,
              'user': {'id': 'user-2', 'username': 'bob'},
            },
          ],
        },
      });
      await pumpEventQueue();
      final friend = controller.state.peopleState.friends.single;

      await controller.openDirectMessage(friend);
      await pumpEventQueue();

      expect(directMessages.openedUserId, 'user-2');
      expect(controller.state.selectedGuildId, discordDirectMessagesGuildId);
      expect(controller.state.selectedChannelId, 'dm-2');
      expect(messages.fetchedChannelId, 'dm-2');
      expect(controller.state.workspace.channels.single.id, 'dm-2');
    });
  });
}

final class _FakeTokenRepository implements TokenRepository {
  _FakeTokenRepository([this.savedToken]);

  String? savedToken;

  @override
  Future<void> clear() async {
    savedToken = null;
  }

  @override
  Future<String?> load() async => savedToken;

  @override
  Future<void> save(String input) async {
    savedToken = input.trim();
  }
}

final class _FakeGatewayConnection implements DiscordGatewayConnection {
  final StreamController<GatewaySessionState> _states =
      StreamController.broadcast();
  final StreamController<Map<String, Object?>> _events =
      StreamController.broadcast();

  String? connectedToken;
  int disconnectCount = 0;
  GatewaySessionState _state = const GatewaySessionState.disconnected();

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  GatewaySessionState get state => _state;

  @override
  Stream<GatewaySessionState> get states => _states.stream;

  @override
  Future<void> connect(String input) async {
    connectedToken = input;
    _state = _state.connectionOpened();
    _states.add(_state);
  }

  @override
  Future<void> updateVoiceState({
    required String guildId,
    required String? channelId,
    required bool selfMute,
    required bool selfDeaf,
  }) async {}

  @override
  Future<void> disconnect() async {
    disconnectCount += 1;
    _state = const GatewaySessionState.disconnected();
    _states.add(_state);
  }

  @override
  Future<void> dispose() async {}

  Future<void> disposeStreams() async {
    await _states.close();
    await _events.close();
  }

  void emitEvent(Map<String, Object?> event) {
    _events.add(Map.unmodifiable(event));
  }

  void emitState(GatewaySessionState state) {
    _state = state;
    _states.add(state);
  }
}

final class _FakeChannelManagementRepository
    implements ChannelManagementRepository {
  String? createdGuildId;
  DiscordCreateChannelRequest? createdRequest;
  String? updatedChannelId;
  DiscordUpdateChannelRequest? updatedRequest;
  String? deletedChannelId;

  @override
  Future<DiscordChannel> createChannel({
    required String guildId,
    required DiscordCreateChannelRequest request,
  }) async {
    createdGuildId = guildId;
    createdRequest = request;
    return const DiscordChannel(
      id: 'channel-new',
      guildId: 'guild-1',
      name: '새 채널',
      type: 0,
      position: 1,
    );
  }

  @override
  Future<DiscordChannel> updateChannel({
    required String channelId,
    required String guildId,
    required DiscordUpdateChannelRequest request,
  }) async {
    updatedChannelId = channelId;
    updatedRequest = request;
    return const DiscordChannel(
      id: 'channel-new',
      guildId: 'guild-1',
      name: '새 이름',
      type: 0,
      position: 1,
    );
  }

  @override
  Future<void> deleteChannel(String channelId) async {
    deletedChannelId = channelId;
  }
}

final class _FakeRoleRepository implements RoleRepository {
  String? createdGuildId;
  String? updatedRoleId;
  Map<String, int>? updatedPositions;
  String? deletedRoleId;

  @override
  Future<DiscordRole> createRole({
    required String guildId,
    required DiscordRoleRequest request,
  }) async {
    createdGuildId = guildId;
    return DiscordRole(
      id: 'role-new',
      name: request.name,
      position: 1,
      permissions: request.permissions,
    );
  }

  @override
  Future<DiscordRole> updateRole({
    required String guildId,
    required String roleId,
    required DiscordRoleRequest request,
  }) async {
    updatedRoleId = roleId;
    return DiscordRole(
      id: roleId,
      name: request.name,
      position: 1,
      permissions: request.permissions,
    );
  }

  @override
  Future<List<DiscordRole>> updateRolePositions({
    required String guildId,
    required Map<String, int> positions,
  }) async {
    updatedPositions = Map.unmodifiable(positions);
    return [
      DiscordRole(
        id: 'guild-1',
        name: '@everyone',
        position: 0,
        permissions: BigInt.from(1024),
      ),
      DiscordRole(
        id: 'role-new',
        name: '관리자',
        position: 2,
        permissions: BigInt.from(8200),
      ),
    ];
  }

  @override
  Future<void> deleteRole({
    required String guildId,
    required String roleId,
  }) async {
    deletedRoleId = roleId;
  }
}

final class _FakeInviteRepository implements InviteRepository {
  String? loadedGuildId;
  String? createdChannelId;
  String? deletedCode;

  @override
  Future<List<DiscordGuildInvite>> listGuildInvites(String guildId) async {
    loadedGuildId = guildId;
    return const [
      DiscordGuildInvite(
        code: 'abc123',
        channelId: 'channel-1',
        channelName: 'general',
        uses: 0,
        maxUses: 0,
        maxAgeSeconds: 86400,
        temporary: false,
      ),
    ];
  }

  @override
  Future<DiscordGuildInvite> createInvite({
    required String channelId,
    required DiscordInviteRequest request,
  }) async {
    createdChannelId = channelId;
    return const DiscordGuildInvite(
      code: 'new123',
      channelId: 'channel-1',
      channelName: 'general',
      uses: 0,
      maxUses: 1,
      maxAgeSeconds: 86400,
      temporary: false,
    );
  }

  @override
  Future<void> deleteInvite(String code) async {
    deletedCode = code;
  }
}

final class _FakeScheduledEventRepository implements ScheduledEventRepository {
  String? loadedGuildId;
  DiscordExternalEventRequest? createdRequest;
  String? updatedEventId;
  DiscordScheduledEventStatus? updatedStatus;
  String? deletedEventId;

  @override
  Future<List<DiscordScheduledEvent>> listEvents(String guildId) async {
    loadedGuildId = guildId;
    return [_event('event-existing', '기존 모임')];
  }

  @override
  Future<DiscordScheduledEvent> createExternalEvent({
    required String guildId,
    required DiscordExternalEventRequest request,
  }) async {
    createdRequest = request;
    return _event('event-new', request.name);
  }

  @override
  Future<DiscordScheduledEvent> updateExternalEvent({
    required String guildId,
    required String eventId,
    required DiscordExternalEventRequest request,
    DiscordScheduledEventStatus? status,
  }) async {
    updatedEventId = eventId;
    updatedStatus = status;
    return _event(
      eventId,
      request.name,
      status: status ?? DiscordScheduledEventStatus.scheduled,
    );
  }

  @override
  Future<void> deleteEvent({
    required String guildId,
    required String eventId,
  }) async {
    deletedEventId = eventId;
  }
}

DiscordScheduledEvent _event(
  String id,
  String name, {
  DiscordScheduledEventStatus status = DiscordScheduledEventStatus.scheduled,
}) {
  return DiscordScheduledEvent(
    id: id,
    guildId: 'guild-1',
    name: name,
    scheduledStartTime: DateTime.utc(2026, 7, 20, 10),
    scheduledEndTime: DateTime.utc(2026, 7, 20, 12),
    status: status,
    entityType: DiscordScheduledEventEntityType.external,
    location: '서울',
  );
}

final class _FakeMessageRepository implements MessageRepository {
  _FakeMessageRepository({this.initialMessages, this.olderMessages = const []});

  final List<DiscordMessage>? initialMessages;
  final List<DiscordMessage> olderMessages;
  String? sentContent;
  String? repliedToMessageId;
  String? addedReaction;
  String? removedReaction;
  List<DiscordUploadFile> sentAttachments = const [];
  String? attachmentReplyTargetId;
  String? searchQuery;
  String? searchChannelId;
  String? aroundMessageId;
  String? editedContent;
  String? deletedMessageId;
  bool? pinnedValue;
  String? beforeMessageId;
  String? fetchedChannelId;
  List<String> sentStickerIds = const [];
  String? votedMessageId;
  Set<int>? votedAnswerIds;
  int typingCount = 0;

  @override
  Future<void> addReaction(
    String channelId,
    String messageId,
    String emoji,
  ) async {
    addedReaction = emoji;
  }

  @override
  Future<List<DiscordMessage>> fetchMessages(
    String channelId, {
    String? before,
    int limit = 50,
  }) async {
    fetchedChannelId = channelId;
    beforeMessageId = before;
    if (before != null) {
      return olderMessages;
    }
    if (initialMessages case final messages?) {
      return messages;
    }
    return [
      DiscordMessage(
        id: 'message-1',
        channelId: channelId,
        content: '기존 메시지',
        authorId: 'user-1',
        authorName: 'alice',
        timestamp: DateTime.utc(2026, 7, 16, 10),
      ),
    ];
  }

  @override
  Future<List<DiscordMessage>> fetchMessagesAround(
    String channelId,
    String messageId, {
    int limit = 50,
  }) async {
    aroundMessageId = messageId;
    return [
      DiscordMessage(
        id: messageId,
        channelId: channelId,
        content: '검색 결과',
        authorId: 'user-1',
        authorName: 'alice',
        timestamp: DateTime.utc(2026, 7, 16, 10, 3),
      ),
    ];
  }

  @override
  Future<DiscordMessage> editMessage(
    String channelId,
    String messageId,
    String content,
  ) async {
    editedContent = content;
    return DiscordMessage(
      id: messageId,
      channelId: channelId,
      content: content,
      authorId: 'user-1',
      authorName: 'alice',
      timestamp: DateTime.utc(2026, 7, 16, 10),
      editedTimestamp: DateTime.utc(2026, 7, 16, 10, 5),
    );
  }

  @override
  Future<void> deleteMessage(String channelId, String messageId) async {
    deletedMessageId = messageId;
  }

  @override
  Future<DiscordMessage> sendMessage(String channelId, String content) async {
    sentContent = content;
    return DiscordMessage(
      id: 'message-2',
      channelId: channelId,
      content: content,
      authorId: 'user-1',
      authorName: 'alice',
      timestamp: DateTime.utc(2026, 7, 16, 10, 1),
    );
  }

  @override
  Future<DiscordMessage> sendPoll(
    String channelId,
    DiscordPollDraft draft,
  ) async {
    return DiscordMessage(
      id: 'message-poll',
      channelId: channelId,
      content: '',
      authorId: 'user-1',
      authorName: 'alice',
      timestamp: DateTime.utc(2026, 7, 16, 10, 2),
      poll: DiscordPoll(
        question: draft.question,
        answers: [
          for (var index = 0; index < draft.answers.length; index += 1)
            DiscordPollAnswer(
              id: index + 1,
              text: draft.answers[index],
              voteCount: 0,
              meVoted: false,
            ),
        ],
        allowMultiselect: draft.allowMultiselect,
        finalized: false,
      ),
    );
  }

  @override
  Future<void> votePoll(
    String channelId,
    String messageId,
    Set<int> answerIds,
  ) async {
    votedMessageId = messageId;
    votedAnswerIds = Set.unmodifiable(answerIds);
  }

  @override
  Future<DiscordMessage> sendStickers(
    String channelId,
    List<String> stickerIds, {
    String content = '',
  }) async {
    sentStickerIds = List.unmodifiable(stickerIds);
    return DiscordMessage(
      id: 'message-sticker',
      channelId: channelId,
      content: content,
      authorId: 'user-1',
      authorName: 'alice',
      timestamp: DateTime.utc(2026, 7, 16, 10, 2),
      stickers: [
        DiscordSticker(id: stickerIds.single, name: 'Wumpus', formatType: 1),
      ],
    );
  }

  @override
  Future<DiscordMessage> sendReply(
    String channelId,
    String content,
    String messageId,
  ) async {
    repliedToMessageId = messageId;
    return sendMessage(channelId, content);
  }

  @override
  Future<void> removeReaction(
    String channelId,
    String messageId,
    String emoji,
  ) async {
    removedReaction = emoji;
  }

  @override
  Future<void> setPinned(
    String channelId,
    String messageId,
    bool pinned,
  ) async {
    pinnedValue = pinned;
  }

  @override
  Future<void> triggerTyping(String channelId) async {
    typingCount += 1;
  }

  @override
  Future<DiscordMessageSearchResult> searchGuildMessages(
    String guildId,
    String query, {
    String? channelId,
    int offset = 0,
  }) async {
    searchQuery = query;
    searchChannelId = channelId;
    return DiscordMessageSearchResult(
      query: query,
      totalResults: 1,
      messages: [
        DiscordMessage(
          id: 'message-search',
          channelId: 'channel-1',
          content: '검색 결과',
          authorId: 'user-1',
          authorName: 'alice',
          timestamp: DateTime.utc(2026, 7, 16, 10, 3),
        ),
      ],
      threads: [
        _thread(
          id: 'thread-search',
          guildId: guildId,
          parentId: 'channel-1',
          name: '검색된 스레드',
        ),
      ],
    );
  }

  @override
  Future<DiscordMessage> sendAttachments(
    String channelId,
    String content,
    List<DiscordUploadFile> files, {
    String? replyToMessageId,
  }) async {
    sentAttachments = List.unmodifiable(files);
    attachmentReplyTargetId = replyToMessageId;
    return DiscordMessage(
      id: 'message-attachment',
      channelId: channelId,
      content: content,
      authorId: 'user-1',
      authorName: 'alice',
      timestamp: DateTime.utc(2026, 7, 16, 10, 2),
      attachments: [
        DiscordAttachment(
          id: 'attachment-1',
          filename: files.single.filename,
          url: 'https://cdn.discordapp.com/attachments/image.png',
          proxyUrl: 'https://media.discordapp.net/attachments/image.png',
          contentType: files.single.contentType,
          size: files.single.bytes.length,
        ),
      ],
    );
  }
}

final class _FakeClientSyncRepository implements ClientSyncRepository {
  _FakeClientSyncRepository({this.error});

  final Object? error;
  List<String> acknowledgedMessageIds = const [];

  @override
  Future<void> acknowledgeRead(String channelId, String messageId) async {
    acknowledgedMessageIds = List.unmodifiable([
      ...acknowledgedMessageIds,
      messageId,
    ]);
    if (error case final value?) {
      throw value;
    }
  }
}

final class _FakeAttachmentDownloadService
    implements AttachmentDownloadService {
  String? downloadedAttachmentId;

  @override
  Future<String?> download(DiscordAttachment attachment) async {
    downloadedAttachmentId = attachment.id;
    return r'C:\Downloads\image.png';
  }
}

final class _FakeTypingExpiryScheduler implements TypingExpiryScheduler {
  Duration? duration;
  void Function()? _callback;

  @override
  TypingExpiryTask schedule(Duration duration, void Function() callback) {
    this.duration = duration;
    _callback = callback;
    return _FakeTypingExpiryTask();
  }

  void expire() => _callback?.call();
}

final class _FakeTypingExpiryTask implements TypingExpiryTask {
  @override
  void cancel() {}
}

final class _FakeThreadRepository implements ThreadRepository {
  String? listedParentChannelId;
  String? createdName;
  String? joinedThreadId;
  String? archivedThreadId;
  String? startedFromMessageId;
  String? forumChannelId;
  String? forumTitle;
  String? forumContent;
  List<String> forumTagIds = const [];

  @override
  Future<DiscordChannel> createPublicThread({
    required String guildId,
    required String parentChannelId,
    required String name,
  }) async {
    createdName = name;
    return _thread(
      id: 'thread-new',
      guildId: guildId,
      parentId: parentChannelId,
      name: name,
    );
  }

  @override
  Future<DiscordChannel> createForumPost({
    required String guildId,
    required String forumChannelId,
    required String title,
    required String content,
    List<String> appliedTagIds = const [],
  }) async {
    this.forumChannelId = forumChannelId;
    forumTitle = title;
    forumContent = content;
    forumTagIds = List.unmodifiable(appliedTagIds);
    return _thread(
      id: 'post-new',
      guildId: guildId,
      parentId: forumChannelId,
      name: title,
    );
  }

  @override
  Future<void> joinThread(String threadId) async {
    joinedThreadId = threadId;
  }

  @override
  Future<List<DiscordChannel>> listThreads({
    required String guildId,
    required String parentChannelId,
    bool includePrivateArchived = true,
  }) async {
    listedParentChannelId = parentChannelId;
    return [
      _thread(
        id: 'thread-archived',
        guildId: guildId,
        parentId: parentChannelId,
        name: '보관됨',
        archived: true,
      ),
    ];
  }

  @override
  Future<DiscordChannel> setArchived({
    required String guildId,
    required String threadId,
    required bool archived,
  }) async {
    archivedThreadId = threadId;
    return _thread(
      id: threadId,
      guildId: guildId,
      parentId: 'channel-1',
      name: '새 스레드',
      archived: archived,
      joined: true,
    );
  }

  @override
  Future<DiscordChannel> startThreadFromMessage({
    required String guildId,
    required String channelId,
    required String messageId,
    required String name,
  }) async {
    startedFromMessageId = messageId;
    return _thread(
      id: 'thread-message',
      guildId: guildId,
      parentId: channelId,
      name: name,
    );
  }
}

final class _FakeRelationshipRepository implements RelationshipRepository {
  String? requestedUsername;
  String? acceptedUserId;
  String? blockedUserId;
  String? removedUserId;

  @override
  Future<void> acceptFriendRequest(String userId) async {
    acceptedUserId = userId;
  }

  @override
  Future<void> blockUser(String userId) async {
    blockedUserId = userId;
  }

  @override
  Future<void> removeRelationship(String userId) async {
    removedUserId = userId;
  }

  @override
  Future<void> sendFriendRequest(String username) async {
    requestedUsername = username.trim();
  }
}

final class _FakeDirectMessageRepository implements DirectMessageRepository {
  String? openedUserId;

  @override
  Future<DiscordChannel> openDirectMessage(String userId) async {
    openedUserId = userId;
    return const DiscordChannel(
      id: 'dm-2',
      guildId: discordDirectMessagesGuildId,
      name: 'bob',
      type: 1,
      position: 0,
      recipients: [DiscordUser(id: 'user-2', username: 'bob')],
    );
  }
}

DiscordChannel _thread({
  required String id,
  required String guildId,
  required String parentId,
  required String name,
  bool archived = false,
  bool joined = false,
}) {
  return DiscordChannel(
    id: id,
    guildId: guildId,
    name: name,
    type: 11,
    position: 0,
    parentId: parentId,
    joined: joined,
    threadMetadata: DiscordThreadMetadata(
      archived: archived,
      locked: false,
      autoArchiveDuration: 1440,
      archiveTimestamp: DateTime.utc(2026, 7, 16, 10),
    ),
  );
}

final class _FakeReadStateRepository implements ReadStateRepository {
  _FakeReadStateRepository(Map<String, DiscordReadState> initial)
    : _states = Map.unmodifiable(initial);

  Map<String, DiscordReadState> _states;
  List<DiscordReadState> savedStates = const [];

  Map<String, DiscordReadState> get states => _states;

  @override
  Future<void> clear() async {
    _states = const {};
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<Map<String, DiscordReadState>> loadAll() async => _states;

  @override
  Future<void> save(DiscordReadState state) async {
    savedStates = List.unmodifiable([...savedStates, state]);
    _states = Map.unmodifiable({..._states, state.channelId: state});
  }
}
