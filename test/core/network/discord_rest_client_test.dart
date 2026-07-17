import 'package:dio/dio.dart';
import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordRestClient', () {
    test('429 retry_after 이후 동일 요청을 재시도한다', () async {
      final executor = _FakeRequestExecutor([
        const DiscordRestResponse(statusCode: 429, body: {'retry_after': 0.25}),
        const DiscordRestResponse(statusCode: 200, body: {'ok': true}),
      ]);
      final delays = <Duration>[];
      final client = DiscordRestClient(
        token: 'abc.def.ghi',
        executor: executor,
        delay: (duration) async => delays.add(duration),
      );

      final body = await client.get('/users/@me');

      expect(body, {'ok': true});
      expect(executor.requests, hasLength(2));
      expect(delays, [const Duration(milliseconds: 250)]);
    });

    test('성공하지 않은 응답을 명시적 예외로 변환한다', () async {
      final client = DiscordRestClient(
        token: 'abc.def.ghi',
        executor: _FakeRequestExecutor([
          const DiscordRestResponse(
            statusCode: 403,
            body: {'message': 'Missing Access'},
          ),
        ]),
      );

      expect(
        () => client.get('/channels/forbidden'),
        throwsA(
          isA<DiscordHttpException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having((error) => error.message, 'message', 'Missing Access'),
        ),
      );
    });

    test('429가 계속되면 재시도 한도 오류를 반환한다', () async {
      final client = DiscordRestClient(
        token: 'abc.def.ghi',
        executor: _FakeRequestExecutor(
          List.filled(
            4,
            const DiscordRestResponse(
              statusCode: 429,
              body: {'retry_after': 0},
            ),
          ),
        ),
        delay: (_) async {},
      );

      expect(
        () => client.get('/users/@me'),
        throwsA(
          isA<DiscordHttpException>().having(
            (error) => error.statusCode,
            'statusCode',
            429,
          ),
        ),
      );
    });

    test('POST body를 executor에 전달한다', () async {
      final executor = _FakeRequestExecutor([
        const DiscordRestResponse(statusCode: 201, body: {'id': 'message-1'}),
      ]);
      final client = DiscordRestClient(
        token: 'abc.def.ghi',
        executor: executor,
      );

      await client.post(
        '/channels/channel-1/messages',
        data: {'content': 'hello'},
      );

      expect(executor.requests.single.method, 'POST');
      expect(executor.requests.single.data, {'content': 'hello'});
    });

    test('PUT과 DELETE method를 executor에 전달한다', () async {
      final executor = _FakeRequestExecutor([
        const DiscordRestResponse(statusCode: 204),
        const DiscordRestResponse(statusCode: 204),
        const DiscordRestResponse(statusCode: 200, body: {'archived': true}),
      ]);
      final client = DiscordRestClient(
        token: 'abc.def.ghi',
        executor: executor,
      );

      await client.put('/reactions/emoji/@me');
      await client.delete('/reactions/emoji/@me');
      await client.patch('/channels/thread-1', data: {'archived': true});

      expect(executor.requests.map((request) => request.method), [
        'PUT',
        'DELETE',
        'PATCH',
      ]);
    });

    test('multipart payload_json과 files 배열을 FormData로 변환한다', () async {
      final executor = _FakeRequestExecutor([
        const DiscordRestResponse(statusCode: 200, body: {'id': 'message-1'}),
      ]);
      final client = DiscordRestClient(
        token: 'abc.def.ghi',
        executor: executor,
      );

      await client.postMultipart(
        '/channels/channel-1/messages',
        payload: {
          'content': '파일',
          'attachments': [
            {'id': 0, 'filename': 'image.png'},
          ],
        },
        files: const [
          DiscordUploadFile(
            filename: 'image.png',
            bytes: [1, 2, 3],
            contentType: 'image/png',
          ),
        ],
      );

      expect(executor.requests.single.data, isA<FormData>());
      final data = executor.requests.single.data as FormData;
      expect(data.fields.single.key, 'payload_json');
      expect(data.files.single.key, 'files[0]');
      expect(data.files.single.value.filename, 'image.png');
    });

    test('multipart 요청은 JSON Content-Type을 강제하지 않는다', () async {
      late RequestOptions observed;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            observed = options;
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: const {'ok': true},
              ),
            );
          },
        ),
      );
      final executor = DioDiscordRequestExecutor(dio);

      await executor.execute(
        DiscordRestRequest(
          method: 'POST',
          path: '/channels/channel-1/messages',
          data: FormData.fromMap({
            'files[0]': MultipartFile.fromBytes(const [
              1,
              2,
              3,
            ], filename: 'image.png'),
          }),
        ),
        'abc.def.ghi',
      );

      expect(observed.headers['Authorization'], 'abc.def.ghi');
      expect(observed.headers['Content-Type'], isNot('application/json'));
    });
  });
}

final class _FakeRequestExecutor implements DiscordRequestExecutor {
  _FakeRequestExecutor(List<DiscordRestResponse> responses)
    : _responses = List.unmodifiable(responses);

  List<DiscordRestResponse> _responses;
  List<DiscordRestRequest> requests = const [];

  @override
  Future<DiscordRestResponse> execute(
    DiscordRestRequest request,
    String token,
  ) async {
    requests = List.unmodifiable([...requests, request]);
    final response = _responses.first;
    _responses = List.unmodifiable(_responses.skip(1));
    return response;
  }
}
