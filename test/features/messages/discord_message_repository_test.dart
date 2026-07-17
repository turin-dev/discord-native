import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/messages/data/discord_message_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordMessageRepository', () {
    test('채널 히스토리를 최신순 API 응답에서 시간순으로 반환한다', () async {
      final api = _FakeDiscordRestApi(
        getResponse: [
          {
            'id': 'message-2',
            'channel_id': 'channel-1',
            'content': '둘째',
            'timestamp': '2026-07-16T10:01:00.000Z',
            'author': {'id': 'user-1', 'username': 'alice'},
          },
          {
            'id': 'message-1',
            'channel_id': 'channel-1',
            'content': '첫째',
            'timestamp': '2026-07-16T10:00:00.000Z',
            'author': {'id': 'user-1', 'username': 'alice'},
          },
        ],
      );
      final repository = DiscordMessageRepository(api);

      final messages = await repository.fetchMessages('channel-1');

      expect(messages.map((message) => message.content), ['첫째', '둘째']);
      expect(api.lastPath, '/channels/channel-1/messages');
      expect(api.lastQuery, {'limit': 50});
    });

    test('과거 히스토리는 before cursor와 최대 100개 limit을 전달한다', () async {
      final api = _FakeDiscordRestApi(getResponse: const []);
      final repository = DiscordMessageRepository(api);

      await repository.fetchMessages(
        'channel-1',
        before: 'message-50',
        limit: 200,
      );

      expect(api.lastQuery, {'limit': 100, 'before': 'message-50'});
    });

    test('공백 메시지는 API 호출 전에 거부한다', () async {
      final api = _FakeDiscordRestApi();
      final repository = DiscordMessageRepository(api);

      expect(
        () => repository.sendMessage('channel-1', '   '),
        throwsA(isA<InvalidMessageException>()),
      );
      expect(api.postCount, 0);
    });

    test('메시지 내용을 정규화해 전송하고 응답을 파싱한다', () async {
      final api = _FakeDiscordRestApi(
        postResponse: {
          'id': 'message-1',
          'channel_id': 'channel-1',
          'content': '안녕하세요',
          'timestamp': '2026-07-16T10:00:00.000Z',
          'author': {'id': 'user-1', 'username': 'alice'},
        },
      );
      final repository = DiscordMessageRepository(api);

      final message = await repository.sendMessage('channel-1', '  안녕하세요  ');

      expect(message.content, '안녕하세요');
      expect(api.lastData, {'content': '안녕하세요'});
    });

    test('최대 3개의 sticker ID와 선택적 내용을 메시지로 전송한다', () async {
      final api = _FakeDiscordRestApi(
        postResponse: {
          'id': 'message-sticker',
          'channel_id': 'channel-1',
          'content': '축하해요',
          'timestamp': '2026-07-16T10:00:00.000Z',
          'author': {'id': 'user-1', 'username': 'alice'},
          'sticker_items': [
            {'id': 'sticker-1', 'name': 'Wumpus', 'format_type': 1},
          ],
        },
      );
      final repository = DiscordMessageRepository(api);

      final message = await repository.sendStickers('channel-1', const [
        'sticker-1',
      ], content: '  축하해요  ');

      expect(message.stickers.single.id, 'sticker-1');
      expect(api.lastData, {
        'content': '축하해요',
        'sticker_ids': ['sticker-1'],
      });
      expect(
        () => repository.sendStickers('channel-1', const ['1', '2', '3', '4']),
        throwsA(isA<InvalidMessageException>()),
      );
    });

    test('답장 reference를 포함해 메시지를 전송한다', () async {
      final api = _FakeDiscordRestApi(
        postResponse: {
          'id': 'message-2',
          'channel_id': 'channel-1',
          'content': '답장',
          'timestamp': '2026-07-16T10:01:00.000Z',
          'author': {'id': 'user-1', 'username': 'alice'},
        },
      );
      final repository = DiscordMessageRepository(api);

      await repository.sendReply('channel-1', '답장', 'message-1');

      expect(api.lastData, {
        'content': '답장',
        'message_reference': {
          'message_id': 'message-1',
          'channel_id': 'channel-1',
          'fail_if_not_exists': false,
        },
      });
    });

    test('reaction emoji를 URL encoding해 추가하고 제거한다', () async {
      final api = _FakeDiscordRestApi();
      final repository = DiscordMessageRepository(api);

      await repository.addReaction('channel-1', 'message-1', '파티:123');
      await repository.removeReaction('channel-1', 'message-1', '파티:123');

      expect(api.putPaths.single, contains('%ED%8C%8C%ED%8B%B0%3A123'));
      expect(api.deletePaths.single, contains('%ED%8C%8C%ED%8B%B0%3A123'));
    });

    test('typing indicator endpoint를 호출한다', () async {
      final api = _FakeDiscordRestApi();
      final repository = DiscordMessageRepository(api);

      await repository.triggerTyping('channel-1');

      expect(api.postPaths, ['/channels/channel-1/typing']);
    });

    test('첨부 설명과 파일을 multipart로 전송한다', () async {
      final api = _FakeDiscordRestApi(
        multipartResponse: {
          'id': 'message-3',
          'channel_id': 'channel-1',
          'content': '파일',
          'timestamp': '2026-07-16T10:03:00.000Z',
          'author': {'id': 'user-1', 'username': 'alice'},
          'attachments': [],
        },
      );
      final repository = DiscordMessageRepository(api);

      await repository.sendAttachments('channel-1', '파일', const [
        DiscordUploadFile(
          filename: 'image.png',
          bytes: [1, 2, 3],
          contentType: 'image/png',
          description: '스크린샷',
        ),
      ], replyToMessageId: 'message-1');

      expect(api.multipartPayload?['attachments'], [
        {'id': 0, 'filename': 'image.png', 'description': '스크린샷'},
      ]);
      expect(api.multipartPayload?['message_reference'], {
        'message_id': 'message-1',
        'channel_id': 'channel-1',
        'fail_if_not_exists': false,
      });
      expect(api.multipartFiles.single.filename, 'image.png');
    });

    test('25 MiB를 넘는 첨부는 API 호출 전에 거부한다', () async {
      final api = _FakeDiscordRestApi();
      final repository = DiscordMessageRepository(api);

      expect(
        () => repository.sendAttachments('channel-1', '', [
          DiscordUploadFile(
            filename: 'large.bin',
            bytes: List.filled(25 * 1024 * 1024 + 1, 0),
            contentType: 'application/octet-stream',
          ),
        ]),
        throwsA(isA<InvalidMessageException>()),
      );
      expect(api.multipartFiles, isEmpty);
    });

    test('guild 검색 결과의 nested message와 thread를 파싱한다', () async {
      final api = _FakeDiscordRestApi(
        getResponse: {
          'total_results': 1,
          'messages': [
            [
              {
                'id': 'message-search',
                'channel_id': 'thread-1',
                'content': '검색할 설계 문서',
                'timestamp': '2026-07-16T10:04:00.000Z',
                'author': {'id': 'user-1', 'username': 'alice'},
                'attachments': [],
              },
            ],
          ],
          'threads': [
            {
              'id': 'thread-1',
              'guild_id': 'guild-1',
              'parent_id': 'channel-1',
              'name': '설계 토론',
              'type': 11,
              'position': 0,
              'thread_metadata': {
                'archived': false,
                'locked': false,
                'auto_archive_duration': 1440,
                'archive_timestamp': '2026-07-16T10:00:00.000Z',
              },
            },
          ],
          'members': [
            {'id': 'thread-1', 'user_id': 'user-1'},
          ],
        },
      );
      final repository = DiscordMessageRepository(api);

      final result = await repository.searchGuildMessages(
        'guild-1',
        '  설계  ',
        channelId: 'channel-1',
      );

      expect(api.lastPath, '/guilds/guild-1/messages/search');
      expect(api.lastQuery, {
        'content': '설계',
        'channel_id': ['channel-1'],
        'limit': 25,
        'offset': 0,
        'sort_by': 'relevance',
        'sort_order': 'desc',
      });
      expect(result.totalResults, 1);
      expect(result.messages.single.id, 'message-search');
      expect(result.threads.single.id, 'thread-1');
      expect(result.threads.single.joined, isTrue);
    });

    test('검색 index 202 본문은 retry_after 이후 재시도한다', () async {
      final api = _FakeDiscordRestApi(
        getResponses: [
          {'code': 110000, 'retry_after': 0.1},
          {'total_results': 0, 'messages': []},
        ],
      );
      final delays = <Duration>[];
      final repository = DiscordMessageRepository(
        api,
        delay: (duration) async => delays.add(duration),
      );

      final result = await repository.searchGuildMessages('guild-1', '설계');

      expect(api.getCount, 2);
      expect(delays, [const Duration(milliseconds: 100)]);
      expect(result.messages, isEmpty);
    });

    test('검색 결과 주변 메시지를 around parameter로 조회한다', () async {
      final api = _FakeDiscordRestApi(
        getResponse: [
          {
            'id': 'message-around',
            'channel_id': 'channel-1',
            'content': '주변 메시지',
            'timestamp': '2026-07-16T10:05:00.000Z',
            'author': {'id': 'user-1', 'username': 'alice'},
            'attachments': [],
          },
        ],
      );
      final repository = DiscordMessageRepository(api);

      final messages = await repository.fetchMessagesAround(
        'channel-1',
        'message-search',
      );

      expect(api.lastQuery, {'limit': 50, 'around': 'message-search'});
      expect(messages.single.id, 'message-around');
    });

    test('빈 검색어와 1024자를 넘는 검색어는 API 전에 거부한다', () async {
      final api = _FakeDiscordRestApi();
      final repository = DiscordMessageRepository(api);

      expect(
        () => repository.searchGuildMessages('guild-1', ' '),
        throwsA(isA<InvalidMessageSearchException>()),
      );
      expect(
        () => repository.searchGuildMessages(
          'guild-1',
          List.filled(1025, 'a').join(),
        ),
        throwsA(isA<InvalidMessageSearchException>()),
      );
      expect(api.getCount, 0);
    });

    test('메시지를 편집·삭제하고 새 pin endpoint를 사용한다', () async {
      final api = _FakeDiscordRestApi(
        patchResponse: {
          'id': 'message-1',
          'channel_id': 'channel-1',
          'content': '수정됨',
          'timestamp': '2026-07-16T10:00:00.000Z',
          'edited_timestamp': '2026-07-16T10:06:00.000Z',
          'author': {'id': 'user-1', 'username': 'alice'},
          'attachments': [],
          'pinned': false,
        },
      );
      final repository = DiscordMessageRepository(api);

      final edited = await repository.editMessage(
        'channel-1',
        'message-1',
        '  수정됨  ',
      );
      await repository.deleteMessage('channel-1', 'message-1');
      await repository.setPinned('channel-1', 'message-1', true);
      await repository.setPinned('channel-1', 'message-1', false);

      expect(api.lastPatchPath, '/channels/channel-1/messages/message-1');
      expect(api.lastPatchData, {'content': '수정됨'});
      expect(edited.content, '수정됨');
      expect(api.putPaths, ['/channels/channel-1/messages/pins/message-1']);
      expect(api.deletePaths, [
        '/channels/channel-1/messages/message-1',
        '/channels/channel-1/messages/pins/message-1',
      ]);
    });

    test('빈 편집 내용과 2000자를 넘는 편집은 API 전에 거부한다', () async {
      final api = _FakeDiscordRestApi();
      final repository = DiscordMessageRepository(api);

      expect(
        () => repository.editMessage('channel-1', 'message-1', ' '),
        throwsA(isA<InvalidMessageException>()),
      );
      expect(
        () => repository.editMessage(
          'channel-1',
          'message-1',
          List.filled(2001, 'a').join(),
        ),
        throwsA(isA<InvalidMessageException>()),
      );
      expect(api.lastPatchPath, isNull);
    });
  });
}

final class _FakeDiscordRestApi implements DiscordRestApi {
  _FakeDiscordRestApi({
    this.getResponse,
    List<Object?> getResponses = const [],
    this.postResponse,
    this.multipartResponse,
    this.patchResponse,
  }) : _getResponses = List.unmodifiable(getResponses);

  final Object? getResponse;
  List<Object?> _getResponses;
  final Object? postResponse;
  final Object? multipartResponse;
  final Object? patchResponse;
  String? lastPath;
  Map<String, Object?>? lastQuery;
  int getCount = 0;
  Object? lastData;
  int postCount = 0;
  List<String> postPaths = const [];
  List<String> putPaths = const [];
  List<String> deletePaths = const [];
  Map<String, Object?>? multipartPayload;
  List<DiscordUploadFile> multipartFiles = const [];
  String? lastPatchPath;
  Object? lastPatchData;

  @override
  Future<Object?> get(
    String path, {
    Map<String, Object?> queryParameters = const {},
  }) async {
    getCount += 1;
    lastPath = path;
    lastQuery = Map.unmodifiable(queryParameters);
    if (_getResponses.isNotEmpty) {
      final response = _getResponses.first;
      _getResponses = List.unmodifiable(_getResponses.skip(1));
      return response;
    }
    return getResponse;
  }

  @override
  Future<Object?> post(String path, {Object? data}) async {
    postCount += 1;
    postPaths = List.unmodifiable([...postPaths, path]);
    lastData = data;
    return postResponse;
  }

  @override
  Future<Object?> patch(String path, {Object? data}) async {
    lastPatchPath = path;
    lastPatchData = data;
    return patchResponse;
  }

  @override
  Future<Object?> put(String path, {Object? data}) async {
    putPaths = List.unmodifiable([...putPaths, path]);
    return null;
  }

  @override
  Future<Object?> delete(String path) async {
    deletePaths = List.unmodifiable([...deletePaths, path]);
    return null;
  }

  @override
  Future<Object?> postMultipart(
    String path, {
    required Map<String, Object?> payload,
    required List<DiscordUploadFile> files,
  }) async {
    multipartPayload = Map.unmodifiable(payload);
    multipartFiles = List.unmodifiable(files);
    return multipartResponse;
  }
}
