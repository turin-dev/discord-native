import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordMessageState', () {
    test('MESSAGE_CREATE를 선택 채널 끝에 추가한다', () {
      final state = const DiscordMessageState(channelId: 'channel-1');

      final updated = state.payloadReceived({
        'op': 0,
        't': 'MESSAGE_CREATE',
        'd': {
          'id': 'message-1',
          'channel_id': 'channel-1',
          'content': '안녕하세요',
          'timestamp': '2026-07-16T10:00:00.000Z',
          'author': {'id': 'user-1', 'username': 'alice'},
        },
      });

      expect(updated.messages.single.content, '안녕하세요');
      expect(state.messages, isEmpty);
    });

    test('다른 채널 이벤트는 무시한다', () {
      final state = const DiscordMessageState(channelId: 'channel-1');

      final updated = state.payloadReceived({
        'op': 0,
        't': 'MESSAGE_CREATE',
        'd': {
          'id': 'message-1',
          'channel_id': 'channel-2',
          'content': '다른 채널',
          'timestamp': '2026-07-16T10:00:00.000Z',
          'author': {'id': 'user-1', 'username': 'alice'},
        },
      });

      expect(identical(updated, state), isTrue);
    });

    test('MESSAGE_UPDATE와 MESSAGE_DELETE를 반영한다', () {
      final initial = DiscordMessageState.loaded('channel-1', [
        DiscordMessage(
          id: 'message-1',
          channelId: 'channel-1',
          content: '원본',
          authorId: 'user-1',
          authorName: 'alice',
          timestamp: DateTime.utc(2026, 7, 16, 10),
          pinned: false,
        ),
      ]);

      final updated = initial.payloadReceived({
        'op': 0,
        't': 'MESSAGE_UPDATE',
        'd': {
          'id': 'message-1',
          'channel_id': 'channel-1',
          'content': '수정됨',
          'edited_timestamp': '2026-07-16T10:01:00.000Z',
          'pinned': true,
        },
      });
      final deleted = updated.payloadReceived({
        'op': 0,
        't': 'MESSAGE_DELETE',
        'd': {'id': 'message-1', 'channel_id': 'channel-1'},
      });

      expect(updated.messages.single.content, '수정됨');
      expect(updated.messages.single.authorName, 'alice');
      expect(updated.messages.single.timestamp, DateTime.utc(2026, 7, 16, 10));
      expect(updated.messages.single.editedTimestamp, isNotNull);
      expect(updated.messages.single.pinned, isTrue);
      expect(deleted.messages, isEmpty);
    });

    test('reply, attachment, reaction payload를 보존한다', () {
      final state = const DiscordMessageState(channelId: 'channel-1');

      final updated = state.payloadReceived({
        'op': 0,
        't': 'MESSAGE_CREATE',
        'd': {
          'id': 'message-2',
          'channel_id': 'channel-1',
          'content': '답장입니다',
          'timestamp': '2026-07-16T10:02:00.000Z',
          'author': {'id': 'user-2', 'username': 'bob'},
          'message_reference': {
            'message_id': 'message-1',
            'channel_id': 'channel-1',
          },
          'referenced_message': {
            'id': 'message-1',
            'channel_id': 'channel-1',
            'content': '원문',
            'timestamp': '2026-07-16T10:00:00.000Z',
            'author': {'id': 'user-1', 'username': 'alice'},
          },
          'attachments': [
            {
              'id': 'attachment-1',
              'filename': 'image.png',
              'url': 'https://cdn.discordapp.com/image.png',
              'proxy_url': 'https://media.discordapp.net/image.png',
              'size': 1024,
              'content_type': 'image/png',
              'width': 320,
              'height': 200,
            },
          ],
          'reactions': [
            {
              'count': 2,
              'me': true,
              'emoji': {'id': null, 'name': '👍'},
            },
          ],
        },
      });

      final message = updated.messages.single;
      expect(message.referencedMessage?.authorName, 'alice');
      expect(message.attachments.single.filename, 'image.png');
      expect(message.reactions.single.count, 2);
      expect(message.reactions.single.me, isTrue);
    });

    test('embed, sticker, mention과 custom emoji 표시 문구를 보존한다', () {
      final message = DiscordMessage.fromJson({
        'id': 'message-rich',
        'channel_id': 'channel-1',
        'content': '**안녕** <@user-2> <#channel-2> <@&role-1> <:party:emoji-1>',
        'timestamp': '2026-07-16T10:03:00.000Z',
        'author': {'id': 'user-1', 'username': 'alice'},
        'mentions': [
          {'id': 'user-2', 'username': 'bob', 'global_name': '밥'},
        ],
        'mention_roles': ['role-1'],
        'embeds': [
          {
            'title': 'Flutter',
            'description': 'Windows 네이티브 클라이언트',
            'url': 'https://flutter.dev',
            'color': 0x5865F2,
            'fields': [
              {'name': '상태', 'value': '개발 중', 'inline': true},
            ],
            'image': {
              'url': 'https://example.com/image.png',
              'proxy_url': 'https://example.com/proxy.png',
              'width': 640,
              'height': 360,
            },
            'footer': {'text': 'Discord Native'},
            'author': {'name': 'OpenAI'},
          },
        ],
        'sticker_items': [
          {'id': 'sticker-1', 'name': 'Wumpus', 'format_type': 1},
        ],
      });

      expect(message.mentions.single.displayName, '밥');
      expect(message.mentionRoleIds, ['role-1']);
      expect(message.embeds.single.title, 'Flutter');
      expect(message.embeds.single.fields.single.value, '개발 중');
      expect(message.embeds.single.image?.width, 640);
      expect(message.stickers.single.name, 'Wumpus');
      expect(message.displayContent, '**안녕** @밥 #channel-2 @role-1 :party:');
      expect(
        message.markdownContent,
        contains(
          '![:party:](https://cdn.discordapp.com/emojis/emoji-1.png?size=48&quality=lossless)',
        ),
      );
    });

    test('과거 메시지를 중복 없이 앞에 병합하고 pagination 상태를 갱신한다', () {
      final current = DiscordMessage(
        id: 'message-2',
        channelId: 'channel-1',
        content: '현재',
        authorId: 'user-1',
        authorName: 'alice',
        timestamp: DateTime.utc(2026, 7, 16, 10, 2),
      );
      final older = DiscordMessage(
        id: 'message-1',
        channelId: 'channel-1',
        content: '과거',
        authorId: 'user-2',
        authorName: 'bob',
        timestamp: DateTime.utc(2026, 7, 16, 10, 1),
      );
      final state = DiscordMessageState.loaded('channel-1', [
        current,
      ], hasMore: true);

      final loading = state.loadingOlder();
      final loaded = loading.prependOlder([older, current], hasMore: false);

      expect(loading.isLoadingOlder, isTrue);
      expect(loaded.messages.map((message) => message.id), [
        'message-1',
        'message-2',
      ]);
      expect(loaded.isLoadingOlder, isFalse);
      expect(loaded.hasMore, isFalse);
    });

    test('투표 질문, 답변, 집계와 내 선택을 파싱한다', () {
      final message = DiscordMessage.fromJson({
        'id': 'message-poll',
        'channel_id': 'channel-1',
        'content': '',
        'timestamp': '2026-07-16T10:03:00.000Z',
        'author': {'id': 'user-1', 'username': 'alice'},
        'poll': {
          'question': {'text': '점심 메뉴는?'},
          'answers': [
            {
              'answer_id': 1,
              'poll_media': {'text': '김치찌개'},
            },
            {
              'answer_id': 2,
              'poll_media': {'text': '돈가스'},
            },
          ],
          'expiry': '2026-07-17T10:03:00.000Z',
          'allow_multiselect': false,
          'layout_type': 1,
          'results': {
            'is_finalized': false,
            'answer_counts': [
              {'id': 1, 'count': 3, 'me_voted': true},
              {'id': 2, 'count': 1, 'me_voted': false},
            ],
          },
        },
      });

      expect(message.poll?.question, '점심 메뉴는?');
      expect(message.poll?.answers.map((answer) => answer.text), [
        '김치찌개',
        '돈가스',
      ]);
      expect(message.poll?.answers.first.voteCount, 3);
      expect(message.poll?.answers.first.meVoted, isTrue);
      expect(message.poll?.totalVotes, 4);
    });

    test('poll 선택을 불변 갱신하고 내 Gateway event를 중복 집계하지 않는다', () {
      final state = DiscordMessageState.loaded('channel-1', [_pollMessage()]);

      final selected = state.setPollSelection('message-poll', {2});
      final afterOwnEvent = selected.payloadReceived({
        'op': 0,
        't': 'MESSAGE_POLL_VOTE_ADD',
        'd': {
          'channel_id': 'channel-1',
          'message_id': 'message-poll',
          'user_id': 'user-me',
          'answer_id': 2,
        },
      }, currentUserId: 'user-me');

      expect(state.messages.single.poll?.answers.first.meVoted, isTrue);
      expect(selected.messages.single.poll?.answers.first.meVoted, isFalse);
      expect(selected.messages.single.poll?.answers.last.meVoted, isTrue);
      expect(selected.messages.single.poll?.answers.last.voteCount, 2);
      expect(afterOwnEvent.messages.single.poll?.answers.last.voteCount, 2);
    });

    test('다른 사용자의 poll Gateway event를 집계한다', () {
      final state = DiscordMessageState.loaded('channel-1', [_pollMessage()]);

      final added = state.payloadReceived({
        'op': 0,
        't': 'MESSAGE_POLL_VOTE_ADD',
        'd': {
          'channel_id': 'channel-1',
          'message_id': 'message-poll',
          'user_id': 'user-other',
          'answer_id': 2,
        },
      }, currentUserId: 'user-me');

      expect(added.messages.single.poll?.answers.last.voteCount, 2);
      expect(added.messages.single.poll?.answers.last.meVoted, isFalse);
    });
  });
}

DiscordMessage _pollMessage() {
  return DiscordMessage(
    id: 'message-poll',
    channelId: 'channel-1',
    content: '',
    authorId: 'user-author',
    authorName: 'alice',
    timestamp: DateTime.utc(2026, 7, 16, 10),
    poll: const DiscordPoll(
      question: '점심 메뉴는?',
      answers: [
        DiscordPollAnswer(id: 1, text: '김치찌개', voteCount: 3, meVoted: true),
        DiscordPollAnswer(id: 2, text: '돈가스', voteCount: 1, meVoted: false),
      ],
      allowMultiselect: false,
      finalized: false,
    ),
  );
}
