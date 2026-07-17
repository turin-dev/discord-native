import 'dart:convert';
import 'dart:io';

import 'package:discord_native/core/gateway/gateway_zlib_stream_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GatewayZlibStreamDecoder', () {
    test('공유 zlib context의 연속 payload를 각각 복원한다', () {
      final encoder = _SharedZlibEncoder();
      final decoder = GatewayZlibStreamDecoder();
      final first = encoder.encode(
        '{"op":10,"d":{"heartbeat_interval":45000}}',
      );
      final second = encoder.encode('{"op":11,"d":null}');

      expect(
        decoder.decode(first),
        '{"op":10,"d":{"heartbeat_interval":45000}}',
      );
      expect(decoder.decode(second), '{"op":11,"d":null}');
    });

    test('flush suffix가 chunk 경계를 가로질러도 payload를 기다린다', () {
      final encoder = _SharedZlibEncoder();
      final decoder = GatewayZlibStreamDecoder();
      final encoded = encoder.encode('{"op":7,"d":null}');
      final split = encoded.length - 2;

      expect(decoder.decode(encoded.sublist(0, split)), isNull);
      expect(decoder.decode(encoded.sublist(split)), '{"op":7,"d":null}');
    });

    test('텍스트 payload는 그대로 통과시킨다', () {
      final decoder = GatewayZlibStreamDecoder();

      expect(decoder.decode('{"op":11,"d":null}'), '{"op":11,"d":null}');
    });
  });
}

final class _SharedZlibEncoder {
  final RawZLibFilter _filter = RawZLibFilter.deflateFilter();

  List<int> encode(String value) {
    final input = utf8.encode(value);
    _filter.process(input, 0, input.length);
    final output = <int>[];
    while (true) {
      final processed = _filter.processed();
      if (processed == null) {
        return List.unmodifiable(output);
      }
      output.addAll(processed);
    }
  }
}
