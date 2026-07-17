import 'dart:typed_data';

final class DiscordPcmFrameAssembler {
  static const int sampleRate = 48000;
  static const int channels = 2;
  static const int frameDurationMilliseconds = 20;
  static const int samplesPerChannel = 960;
  static const int bytesPerSample = 2;
  static const int samplesPerFrame = samplesPerChannel * channels;
  static const int bytesPerFrame = samplesPerFrame * bytesPerSample;

  Uint8List _pending = Uint8List(0);

  int get pendingByteCount => _pending.length;

  List<Int16List> add(Uint8List chunk) {
    if (chunk.isEmpty) {
      return const [];
    }
    final combined = Uint8List(_pending.length + chunk.length)
      ..setAll(0, _pending)
      ..setAll(_pending.length, chunk);
    final frameCount = combined.length ~/ bytesPerFrame;
    final frames = List<Int16List>.generate(
      frameCount,
      (index) => _decodeFrame(
        Uint8List.sublistView(
          combined,
          index * bytesPerFrame,
          (index + 1) * bytesPerFrame,
        ),
      ),
      growable: false,
    );
    _pending = Uint8List.fromList(combined.sublist(frameCount * bytesPerFrame));
    return List.unmodifiable(frames);
  }

  void reset() {
    _pending = Uint8List(0);
  }

  Int16List _decodeFrame(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    return Int16List.fromList(
      List<int>.generate(
        samplesPerFrame,
        (index) => data.getInt16(index * bytesPerSample, Endian.little),
        growable: false,
      ),
    );
  }
}
