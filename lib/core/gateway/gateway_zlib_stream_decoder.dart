import 'dart:convert';
import 'dart:io';

abstract interface class GatewayMessageDecoder {
  Object? decode(Object? message);

  void reset();
}

final class GatewayZlibStreamDecoder implements GatewayMessageDecoder {
  static const List<int> _flushSuffix = [0x00, 0x00, 0xFF, 0xFF];

  RawZLibFilter _inflater = RawZLibFilter.inflateFilter();
  List<int> _buffer = const [];

  @override
  Object? decode(Object? message) {
    if (message is String || message is Map) {
      return message;
    }
    if (message is! List<int>) {
      throw const FormatException('Gateway binary payload 형식이 올바르지 않습니다.');
    }
    _buffer = List.unmodifiable([..._buffer, ...message]);
    if (!_endsWithFlushSuffix(_buffer)) {
      return null;
    }
    _inflater.process(_buffer, 0, _buffer.length);
    _buffer = const [];
    final output = <int>[];
    while (true) {
      final processed = _inflater.processed();
      if (processed == null) {
        return utf8.decode(output);
      }
      output.addAll(processed);
    }
  }

  @override
  void reset() {
    _inflater = RawZLibFilter.inflateFilter();
    _buffer = const [];
  }
}

bool _endsWithFlushSuffix(List<int> bytes) {
  if (bytes.length < GatewayZlibStreamDecoder._flushSuffix.length) {
    return false;
  }
  final offset = bytes.length - GatewayZlibStreamDecoder._flushSuffix.length;
  for (
    var index = 0;
    index < GatewayZlibStreamDecoder._flushSuffix.length;
    index += 1
  ) {
    if (bytes[offset + index] != GatewayZlibStreamDecoder._flushSuffix[index]) {
      return false;
    }
  }
  return true;
}
