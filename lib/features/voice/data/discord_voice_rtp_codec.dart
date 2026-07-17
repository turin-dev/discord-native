import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:discord_native/features/voice/data/discord_voice_gateway_client.dart';

final class DiscordDecodedAudioPacket {
  const DiscordDecodedAudioPacket({
    required this.opusFrame,
    required this.sequence,
    required this.timestamp,
    required this.ssrc,
    required this.nonceCounter,
  });

  final Uint8List opusFrame;
  final int sequence;
  final int timestamp;
  final int ssrc;
  final int nonceCounter;
}

final class DiscordVoiceRtpCodec {
  DiscordVoiceRtpCodec({required this.mode, required Uint8List secretKey})
    : _cipher = _cipherForMode(mode),
      _secretKey = _validatedSecretKey(secretKey);

  final String mode;
  final Cipher _cipher;
  final SecretKey _secretKey;

  Future<Uint8List> encryptAudio({
    required Uint8List opusFrame,
    required int sequence,
    required int timestamp,
    required int ssrc,
    required int nonceCounter,
  }) async {
    _validateRange(sequence, 0xFFFF, 'RTP sequence');
    _validateRange(timestamp, 0xFFFFFFFF, 'RTP timestamp');
    _validateRange(ssrc, 0xFFFFFFFF, 'RTP SSRC');
    _validateRange(nonceCounter, 0xFFFFFFFF, 'RTP nonce');
    if (opusFrame.isEmpty) {
      throw const FormatException('빈 Opus frame은 보낼 수 없습니다.');
    }
    final header = _audioHeader(
      sequence: sequence,
      timestamp: timestamp,
      ssrc: ssrc,
    );
    final nonce = _nonce(nonceCounter, _cipher.nonceLength);
    final secretBox = await _cipher.encrypt(
      opusFrame,
      secretKey: _secretKey,
      nonce: nonce,
      aad: header,
    );
    final encrypted = secretBox.concatenation(nonce: false);
    return Uint8List.fromList([
      ...header,
      ...encrypted,
      ..._nonceSuffix(nonceCounter),
    ]);
  }

  Future<DiscordDecodedAudioPacket> decryptAudio(Uint8List packet) async {
    final header = _parseHeader(packet);
    final nonceOffset = packet.length - _nonceSuffixLength;
    final macOffset = nonceOffset - _authTagLength;
    if (macOffset < header.headerSize) {
      throw const FormatException('Voice RTP payload 길이가 올바르지 않습니다.');
    }
    final nonceCounter = ByteData.sublistView(
      packet,
      nonceOffset,
    ).getUint32(0, Endian.big);
    final nonce = _nonce(nonceCounter, _cipher.nonceLength);
    final secretBox = SecretBox(
      packet.sublist(header.headerSize, macOffset),
      nonce: nonce,
      mac: Mac(packet.sublist(macOffset, nonceOffset)),
    );
    List<int> clearText;
    try {
      clearText = await _cipher.decrypt(
        secretBox,
        secretKey: _secretKey,
        aad: packet.sublist(0, header.headerSize),
      );
    } on SecretBoxAuthenticationError {
      throw const FormatException('Voice RTP packet 인증에 실패했습니다.');
    }
    final opusFrame = _stripRtpMetadata(
      Uint8List.fromList(clearText),
      header: header,
      packet: packet,
    );
    return DiscordDecodedAudioPacket(
      opusFrame: opusFrame,
      sequence: header.sequence,
      timestamp: header.timestamp,
      ssrc: header.ssrc,
      nonceCounter: nonceCounter,
    );
  }
}

final class _DiscordRtpHeader {
  const _DiscordRtpHeader({
    required this.headerSize,
    required this.sequence,
    required this.timestamp,
    required this.ssrc,
    required this.hasPadding,
    required this.hasExtension,
    required this.extensionHeaderOffset,
  });

  final int headerSize;
  final int sequence;
  final int timestamp;
  final int ssrc;
  final bool hasPadding;
  final bool hasExtension;
  final int extensionHeaderOffset;
}

Uint8List _audioHeader({
  required int sequence,
  required int timestamp,
  required int ssrc,
}) {
  final header = Uint8List(12);
  final data = ByteData.sublistView(header);
  header[0] = 0x80;
  header[1] = 0x78;
  data.setUint16(2, sequence, Endian.big);
  data.setUint32(4, timestamp, Endian.big);
  data.setUint32(8, ssrc, Endian.big);
  return header;
}

_DiscordRtpHeader _parseHeader(Uint8List packet) {
  if (packet.length < 12 + _authTagLength + _nonceSuffixLength) {
    throw const FormatException('Voice RTP packet이 너무 짧습니다.');
  }
  final first = packet[0];
  if (first >> 6 != 2) {
    throw const FormatException('Voice RTP version이 올바르지 않습니다.');
  }
  if (packet[1] & 0x7F != 0x78) {
    throw const FormatException('Voice RTP Opus payload type이 아닙니다.');
  }
  final csrcCount = first & 0x0F;
  final hasExtension = first & 0x10 != 0;
  final extensionHeaderOffset = 12 + (csrcCount * 4);
  final headerSize = extensionHeaderOffset + (hasExtension ? 4 : 0);
  if (headerSize + _authTagLength + _nonceSuffixLength > packet.length) {
    throw const FormatException('Voice RTP header 길이가 올바르지 않습니다.');
  }
  final data = ByteData.sublistView(packet);
  return _DiscordRtpHeader(
    headerSize: headerSize,
    sequence: data.getUint16(2, Endian.big),
    timestamp: data.getUint32(4, Endian.big),
    ssrc: data.getUint32(8, Endian.big),
    hasPadding: first & 0x20 != 0,
    hasExtension: hasExtension,
    extensionHeaderOffset: extensionHeaderOffset,
  );
}

Uint8List _stripRtpMetadata(
  Uint8List payload, {
  required _DiscordRtpHeader header,
  required Uint8List packet,
}) {
  var end = payload.length;
  if (header.hasPadding) {
    if (payload.isEmpty) {
      throw const FormatException('Voice RTP padding이 올바르지 않습니다.');
    }
    final paddingLength = payload.last;
    if (paddingLength == 0 || paddingLength > payload.length) {
      throw const FormatException('Voice RTP padding 길이가 올바르지 않습니다.');
    }
    end -= paddingLength;
  }
  var start = 0;
  if (header.hasExtension) {
    final extensionWords = ByteData.sublistView(
      packet,
      header.extensionHeaderOffset + 2,
    ).getUint16(0, Endian.big);
    start = extensionWords * 4;
    if (start > end) {
      throw const FormatException('Voice RTP extension 길이가 올바르지 않습니다.');
    }
  }
  return Uint8List.fromList(payload.sublist(start, end));
}

Cipher _cipherForMode(String mode) {
  return switch (mode) {
    DiscordVoiceGatewayClient.aes256GcmMode => AesGcm.with256bits(),
    DiscordVoiceGatewayClient.xchacha20Poly1305Mode => Xchacha20.poly1305Aead(),
    _ => throw const FormatException('지원하지 않는 Voice AEAD mode입니다.'),
  };
}

SecretKey _validatedSecretKey(Uint8List secretKey) {
  if (secretKey.length != 32) {
    throw const FormatException('Voice AEAD key는 32바이트여야 합니다.');
  }
  return SecretKeyData(Uint8List.fromList(secretKey));
}

Uint8List _nonce(int counter, int length) {
  final nonce = Uint8List(length);
  ByteData.sublistView(nonce).setUint32(0, counter, Endian.big);
  return nonce;
}

Uint8List _nonceSuffix(int counter) {
  final suffix = Uint8List(_nonceSuffixLength);
  ByteData.sublistView(suffix).setUint32(0, counter, Endian.big);
  return suffix;
}

void _validateRange(int value, int maximum, String field) {
  if (value < 0 || value > maximum) {
    throw FormatException('$field 범위가 올바르지 않습니다.');
  }
}

const int _authTagLength = 16;
const int _nonceSuffixLength = 4;
