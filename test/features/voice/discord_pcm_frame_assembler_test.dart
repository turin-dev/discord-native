import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_pcm_frame_assembler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordPcmFrameAssembler', () {
    test('임의 크기의 PCM16 chunk를 정확한 20ms stereo frame으로 조립한다', () {
      final assembler = DiscordPcmFrameAssembler();
      final firstHalf = Uint8List(DiscordPcmFrameAssembler.bytesPerFrame ~/ 2);
      final secondHalf = Uint8List.fromList(
        List<int>.generate(
          DiscordPcmFrameAssembler.bytesPerFrame ~/ 2,
          (index) => index.isEven ? 0x34 : 0x12,
        ),
      );

      expect(assembler.add(firstHalf), isEmpty);
      final frames = assembler.add(secondHalf);

      expect(frames, hasLength(1));
      expect(frames.single, hasLength(1920));
      expect(frames.single.first, 0);
      expect(frames.single[960], 0x1234);
      expect(assembler.pendingByteCount, 0);
    });

    test('여러 frame과 남은 byte를 손실 없이 다음 호출로 넘긴다', () {
      final assembler = DiscordPcmFrameAssembler();
      final bytes = Uint8List.fromList(
        List<int>.generate(
          DiscordPcmFrameAssembler.bytesPerFrame * 2 + 2,
          (index) => index & 0xFF,
        ),
      );

      final frames = assembler.add(bytes);

      expect(frames, hasLength(2));
      expect(assembler.pendingByteCount, 2);

      final completed = assembler.add(
        Uint8List(DiscordPcmFrameAssembler.bytesPerFrame - 2),
      );

      expect(completed, hasLength(1));
      expect(completed.single.first, 0x0100);
      expect(assembler.pendingByteCount, 0);
    });

    test('reset은 조립 중인 PCM byte를 제거한다', () {
      final assembler = DiscordPcmFrameAssembler();
      assembler.add(Uint8List.fromList([1, 2]));

      assembler.reset();

      expect(assembler.pendingByteCount, 0);
    });
  });
}
