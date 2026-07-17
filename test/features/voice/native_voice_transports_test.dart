import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:discord_native/features/voice/data/native_voice_transports.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WebSocketVoiceGatewayTransport', () {
    test('JSON과 binary frame을 전달하고 close code를 노출한다', () async {
      final connection = _FakeVoiceWebSocketConnection();
      Uri? connectedUri;
      final transport = WebSocketVoiceGatewayTransport(
        connector: (uri) {
          connectedUri = uri;
          return connection;
        },
      );

      await transport.connect(Uri.parse('wss://voice.example?v=8'));
      final nextMessage = transport.messages.first;
      connection.addInbound(Uint8List.fromList([1, 2, 3]));
      expect(await nextMessage, Uint8List.fromList([1, 2, 3]));

      await transport.sendJson({
        'op': 3,
        'd': {'t': 1, 'seq_ack': 2},
      });
      await transport.sendBinary(Uint8List.fromList([26, 9, 8]));

      expect(connectedUri, Uri.parse('wss://voice.example?v=8'));
      expect(jsonDecode(connection.sent.first as String), {
        'op': 3,
        'd': {'t': 1, 'seq_ack': 2},
      });
      expect(connection.sent.last, Uint8List.fromList([26, 9, 8]));

      final nextClose = transport.closes.first;
      await connection.finish(4015);
      expect(await nextClose, 4015);

      await transport.close();
      expect(connection.wasClosed, isTrue);
    });

    test('연결 전 전송은 명시적인 StateError를 낸다', () async {
      final transport = WebSocketVoiceGatewayTransport(
        connector: (_) => _FakeVoiceWebSocketConnection(),
      );

      expect(() => transport.sendJson({'op': 0}), throwsStateError);
    });
  });

  group('Voice UDP packets', () {
    test('IP discovery 요청을 74바이트 network byte order로 만든다', () {
      final packet = buildVoiceIpDiscoveryPacket(0x01020304);

      expect(packet, hasLength(74));
      expect(packet.sublist(0, 8), [0, 1, 0, 70, 1, 2, 3, 4]);
      expect(packet.skip(8), everyElement(0));
    });

    test('IP discovery 응답에서 IPv4와 port를 검증해 읽는다', () {
      final packet = Uint8List(74);
      final data = ByteData.sublistView(packet);
      data.setUint16(0, 2, Endian.big);
      data.setUint16(2, 70, Endian.big);
      data.setUint32(4, 99, Endian.big);
      packet.setRange(8, 19, utf8.encode('203.0.113.7'));
      data.setUint16(72, 54321, Endian.big);

      expect(
        parseVoiceIpDiscoveryPacket(packet),
        const VoiceIpDiscoveryResult(address: '203.0.113.7', port: 54321),
      );
    });

    test('잘못된 discovery 응답과 IPv4를 거부한다', () {
      expect(
        () => parseVoiceIpDiscoveryPacket(Uint8List(10)),
        throwsFormatException,
      );
      final packet = Uint8List(74);
      final data = ByteData.sublistView(packet);
      data.setUint16(0, 2, Endian.big);
      data.setUint16(2, 70, Endian.big);
      packet.setRange(8, 17, utf8.encode('not-an-ip'));
      data.setUint16(72, 5000, Endian.big);

      expect(() => parseVoiceIpDiscoveryPacket(packet), throwsFormatException);
    });

    test('UDP keepalive counter를 8바이트 little endian으로 만든다', () {
      final packet = buildVoiceKeepAlivePacket(0x01020304);

      expect(packet, [4, 3, 2, 1, 0, 0, 0, 0]);
    });
  });
}

final class _FakeVoiceWebSocketConnection implements VoiceWebSocketConnection {
  final StreamController<Object?> _inbound = StreamController();

  List<Object> sent = const [];
  bool wasClosed = false;
  int? _closeCode;

  @override
  int? get closeCode => _closeCode;

  @override
  Stream<Object?> get stream => _inbound.stream;

  void addInbound(Object value) => _inbound.add(value);

  Future<void> finish(int code) async {
    _closeCode = code;
    await _inbound.close();
  }

  @override
  Future<void> close() async {
    wasClosed = true;
  }

  @override
  Future<void> get ready async {}

  @override
  void send(Object value) {
    sent = List.unmodifiable([...sent, value]);
  }
}
