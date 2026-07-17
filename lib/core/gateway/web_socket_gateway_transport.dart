import 'dart:convert';

import 'package:discord_native/core/gateway/discord_gateway_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final class WebSocketGatewayTransport implements GatewayTransport {
  WebSocketChannel? _channel;

  @override
  Stream<Object?> get messages {
    final channel = _channel;
    if (channel == null) {
      throw StateError('WebSocket이 연결되지 않았습니다.');
    }
    return channel.stream;
  }

  @override
  Future<void> connect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    _channel = channel;
  }

  @override
  Future<void> send(Map<String, Object?> payload) async {
    final channel = _channel;
    if (channel == null) {
      throw StateError('WebSocket이 연결되지 않았습니다.');
    }
    channel.sink.add(jsonEncode(payload));
  }

  @override
  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }
}
