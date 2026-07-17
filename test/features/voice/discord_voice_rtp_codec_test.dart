import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_voice_gateway_client.dart';
import 'package:discord_native/features/voice/data/discord_voice_rtp_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DiscordVoiceRtpCodec', () {
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));

    for (final mode in [
      DiscordVoiceGatewayClient.aes256GcmMode,
      DiscordVoiceGatewayClient.xchacha20Poly1305Mode,
    ]) {
      test('$mode RTP AEAD 왕복과 wire format을 보존한다', () async {
        final codec = DiscordVoiceRtpCodec(mode: mode, secretKey: key);

        final packet = await codec.encryptAudio(
          opusFrame: Uint8List.fromList([1, 2, 3, 4, 5]),
          sequence: 0x1234,
          timestamp: 0x01020304,
          ssrc: 0x0A0B0C0D,
          nonceCounter: 1,
        );

        expect(packet.sublist(0, 12), [
          0x80,
          0x78,
          0x12,
          0x34,
          1,
          2,
          3,
          4,
          10,
          11,
          12,
          13,
        ]);
        expect(packet.sublist(packet.length - 4), [0, 0, 0, 1]);
        expect(packet, hasLength(12 + 5 + 16 + 4));

        final decoded = await codec.decryptAudio(packet);

        expect(decoded.sequence, 0x1234);
        expect(decoded.timestamp, 0x01020304);
        expect(decoded.ssrc, 0x0A0B0C0D);
        expect(decoded.nonceCounter, 1);
        expect(decoded.opusFrame, [1, 2, 3, 4, 5]);
      });
    }

    test('인증 tag가 변조된 RTP packet을 거부한다', () async {
      final codec = DiscordVoiceRtpCodec(
        mode: DiscordVoiceGatewayClient.aes256GcmMode,
        secretKey: key,
      );
      final packet = await codec.encryptAudio(
        opusFrame: Uint8List.fromList([1, 2, 3]),
        sequence: 1,
        timestamp: 960,
        ssrc: 7,
        nonceCounter: 2,
      );
      final tampered = Uint8List.fromList(packet)..[15] ^= 0xFF;

      expect(() => codec.decryptAudio(tampered), throwsFormatException);
    });

    test('RTP version과 Opus payload type을 경계에서 검증한다', () async {
      final codec = DiscordVoiceRtpCodec(
        mode: DiscordVoiceGatewayClient.xchacha20Poly1305Mode,
        secretKey: key,
      );

      expect(
        () => codec.decryptAudio(Uint8List.fromList(List.filled(40, 0))),
        throwsFormatException,
      );
    });

    test('key, sequence, timestamp, SSRC와 nonce 범위를 검증한다', () {
      expect(
        () => DiscordVoiceRtpCodec(
          mode: DiscordVoiceGatewayClient.aes256GcmMode,
          secretKey: Uint8List(31),
        ),
        throwsFormatException,
      );
      final codec = DiscordVoiceRtpCodec(
        mode: DiscordVoiceGatewayClient.aes256GcmMode,
        secretKey: key,
      );

      expect(
        () => codec.encryptAudio(
          opusFrame: Uint8List.fromList([1]),
          sequence: 65536,
          timestamp: 1,
          ssrc: 1,
          nonceCounter: 1,
        ),
        throwsFormatException,
      );
    });
  });
}
