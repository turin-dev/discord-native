import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:discord_native/core/auth/token_validator.dart';

typedef DelayCallback = Future<void> Function(Duration duration);

final class DiscordUploadFile {
  const DiscordUploadFile({
    required this.filename,
    required this.bytes,
    required this.contentType,
    this.description,
  });

  final String filename;
  final List<int> bytes;
  final String contentType;
  final String? description;
}

final class DiscordRestRequest {
  const DiscordRestRequest({
    required this.method,
    required this.path,
    this.queryParameters = const {},
    this.data,
  });

  final String method;
  final String path;
  final Map<String, Object?> queryParameters;
  final Object? data;
}

final class DiscordRestResponse {
  const DiscordRestResponse({
    required this.statusCode,
    this.body,
    this.headers = const {},
  });

  final int statusCode;
  final Object? body;
  final Map<String, List<String>> headers;
}

abstract interface class DiscordRequestExecutor {
  Future<DiscordRestResponse> execute(DiscordRestRequest request, String token);
}

abstract interface class DiscordRestApi {
  Future<Object?> get(
    String path, {
    Map<String, Object?> queryParameters = const {},
  });

  Future<Object?> post(String path, {Object? data});

  Future<Object?> put(String path, {Object? data});

  Future<Object?> patch(String path, {Object? data});

  Future<Object?> delete(String path);

  Future<Object?> postMultipart(
    String path, {
    required Map<String, Object?> payload,
    required List<DiscordUploadFile> files,
  });
}

final class DiscordHttpException implements Exception {
  const DiscordHttpException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'Discord HTTP $statusCode: $message';
}

final class DiscordRestClient implements DiscordRestApi {
  DiscordRestClient({
    required String token,
    required DiscordRequestExecutor executor,
    DelayCallback delay = Future<void>.delayed,
  }) : _token = TokenValidator.validate(token),
       _executor = executor,
       _delay = delay;

  final String _token;
  final DiscordRequestExecutor _executor;
  final DelayCallback _delay;

  @override
  Future<Object?> get(
    String path, {
    Map<String, Object?> queryParameters = const {},
  }) {
    return _send(
      DiscordRestRequest(
        method: 'GET',
        path: path,
        queryParameters: Map.unmodifiable(queryParameters),
      ),
    );
  }

  @override
  Future<Object?> post(String path, {Object? data}) {
    return _send(DiscordRestRequest(method: 'POST', path: path, data: data));
  }

  @override
  Future<Object?> put(String path, {Object? data}) {
    return _send(DiscordRestRequest(method: 'PUT', path: path, data: data));
  }

  @override
  Future<Object?> patch(String path, {Object? data}) {
    return _send(DiscordRestRequest(method: 'PATCH', path: path, data: data));
  }

  @override
  Future<Object?> delete(String path) {
    return _send(DiscordRestRequest(method: 'DELETE', path: path));
  }

  @override
  Future<Object?> postMultipart(
    String path, {
    required Map<String, Object?> payload,
    required List<DiscordUploadFile> files,
  }) {
    final formData = FormData.fromMap({
      'payload_json': jsonEncode(payload),
      for (var index = 0; index < files.length; index += 1)
        'files[$index]': MultipartFile.fromBytes(
          files[index].bytes,
          filename: files[index].filename,
          contentType: DioMediaType.parse(files[index].contentType),
        ),
    });
    return _send(
      DiscordRestRequest(method: 'POST', path: path, data: formData),
    );
  }

  Future<Object?> _send(DiscordRestRequest request) async {
    for (var attempt = 0; attempt < 4; attempt += 1) {
      final response = await _executor.execute(request, _token);
      if (response.statusCode == 429 && attempt < 3) {
        await _delay(_retryDelay(response.body));
        continue;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
      throw DiscordHttpException(
        statusCode: response.statusCode,
        message: _errorMessage(response.body),
      );
    }
    throw const DiscordHttpException(
      statusCode: 429,
      message: 'Discord 요청 재시도 한도를 초과했습니다.',
    );
  }
}

final class DioDiscordRequestExecutor implements DiscordRequestExecutor {
  DioDiscordRequestExecutor([Dio? dio])
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://discord.com/api/v10',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  @override
  Future<DiscordRestResponse> execute(
    DiscordRestRequest request,
    String token,
  ) async {
    final response = await _dio.request<Object?>(
      request.path,
      data: request.data,
      queryParameters: request.queryParameters,
      options: Options(
        method: request.method,
        headers: {
          'Authorization': token,
          if (request.data is! FormData) 'Content-Type': 'application/json',
        },
        validateStatus: (_) => true,
      ),
    );
    return DiscordRestResponse(
      statusCode: response.statusCode ?? 0,
      body: response.data,
      headers: Map.unmodifiable(response.headers.map),
    );
  }
}

Duration _retryDelay(Object? body) {
  if (body is Map) {
    final retryAfter = body['retry_after'];
    if (retryAfter is num && retryAfter >= 0) {
      return Duration(milliseconds: (retryAfter * 1000).ceil());
    }
  }
  return const Duration(seconds: 1);
}

String _errorMessage(Object? body) {
  if (body is Map && body['message'] is String) {
    return body['message'] as String;
  }
  return 'Discord API 요청에 실패했습니다.';
}
