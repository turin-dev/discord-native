import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:discord_native/core/gateway/gateway_reconnect_policy.dart';
import 'package:discord_native/features/voice/data/discord_dave_controller.dart';
import 'package:discord_native/features/voice/data/discord_dave_session.dart';
import 'package:discord_native/features/voice/data/discord_voice_rtc_transport.dart';
import 'package:discord_native/features/voice/domain/discord_voice_network_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_state.dart';
import 'package:discord_native/features/video/domain/discord_video_protocol.dart';

export 'package:discord_native/features/voice/domain/discord_voice_network_state.dart';
export 'package:discord_native/features/voice/data/discord_voice_rtc_transport.dart';

part 'discord_voice_gateway_reconnect.dart';
part 'discord_voice_gateway_messages.dart';
part 'discord_voice_gateway_video.dart';

abstract interface class VoiceGatewayTransport {
  Stream<Object?> get messages;

  Stream<int?> get closes;

  Future<void> connect(Uri uri);

  Future<void> sendJson(Map<String, Object?> payload);

  Future<void> sendBinary(Uint8List payload);

  Future<void> close();
}

abstract interface class VoiceUdpTransport {
  Stream<Uint8List> get packets;

  Future<VoiceIpDiscoveryResult> connectAndDiscover({
    required String serverAddress,
    required int serverPort,
    required int ssrc,
  });

  Future<void> send(Uint8List packet);

  Future<void> close();
}

abstract interface class VoiceScheduledTask {
  void cancel();
}

abstract interface class VoiceHeartbeatScheduler {
  VoiceScheduledTask schedule(
    Duration interval,
    Future<void> Function() callback,
  );
}

final class TimerVoiceHeartbeatScheduler implements VoiceHeartbeatScheduler {
  const TimerVoiceHeartbeatScheduler();

  @override
  VoiceScheduledTask schedule(
    Duration interval,
    Future<void> Function() callback,
  ) {
    return _TimerVoiceScheduledTask(
      Timer.periodic(interval, (_) => unawaited(callback())),
    );
  }
}

final class _TimerVoiceScheduledTask implements VoiceScheduledTask {
  const _TimerVoiceScheduledTask(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

final class VoiceIpDiscoveryResult {
  const VoiceIpDiscoveryResult({required this.address, required this.port});

  final String address;
  final int port;

  @override
  bool operator ==(Object other) {
    return other is VoiceIpDiscoveryResult &&
        address == other.address &&
        port == other.port;
  }

  @override
  int get hashCode => Object.hash(address, port);
}

final class VoiceGatewayBinaryMessage {
  const VoiceGatewayBinaryMessage({
    required this.sequence,
    required this.opcode,
    required this.payload,
  });

  final int sequence;
  final int opcode;
  final List<int> payload;

  @override
  bool operator ==(Object other) {
    if (other is! VoiceGatewayBinaryMessage ||
        sequence != other.sequence ||
        opcode != other.opcode ||
        payload.length != other.payload.length) {
      return false;
    }
    for (var index = 0; index < payload.length; index += 1) {
      if (payload[index] != other.payload[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(sequence, opcode, Object.hashAll(payload));
}

typedef VoiceNowMilliseconds = int Function();
typedef VoiceReconnectDelay = Future<void> Function(Duration delay);

final class DiscordVoiceGatewayClient {
  DiscordVoiceGatewayClient({
    required VoiceGatewayTransport transport,
    required VoiceUdpTransport udp,
    required DiscordDaveSession daveSession,
    required int maxDaveProtocolVersion,
    DiscordVoiceRtcTransport? rtcTransport,
    VoiceHeartbeatScheduler heartbeatScheduler =
        const TimerVoiceHeartbeatScheduler(),
    VoiceNowMilliseconds? nowMilliseconds,
    VoiceReconnectDelay reconnectDelay = _defaultVoiceReconnectDelay,
    GatewayBackoffPolicy reconnectBackoffPolicy = const GatewayBackoffPolicy(),
    int maxReconnectAttempts = 5,
  }) : _transport = transport,
       _udp = udp,
       _rtcTransport = rtcTransport,
       _maxDaveProtocolVersion = maxDaveProtocolVersion,
       _heartbeatScheduler = heartbeatScheduler,
       _nowMilliseconds =
           nowMilliseconds ?? (() => DateTime.now().millisecondsSinceEpoch),
       _reconnectDelay = reconnectDelay,
       _reconnectBackoffPolicy = reconnectBackoffPolicy,
       _maxReconnectAttempts = maxReconnectAttempts {
    if (maxDaveProtocolVersion < 0 ||
        maxDaveProtocolVersion > daveSession.maxSupportedProtocolVersion) {
      throw const FormatException('DAVE 최대 protocol version이 올바르지 않습니다.');
    }
    if (maxReconnectAttempts < 1 || maxReconnectAttempts > 10) {
      throw const FormatException('Voice 재연결 횟수 범위가 올바르지 않습니다.');
    }
    _dave = DiscordDaveController(
      session: daveSession,
      sendJson: (opcode, data) =>
          _transport.sendJson({'op': opcode, 'd': data}),
      sendBinary: sendBinary,
    );
    final mediaTransport = rtcTransport;
    if (mediaTransport is DiscordVoiceRtcMediaTransport) {
      _rtcErrorSubscription = mediaTransport.errors.listen(
        _fail,
        onError: (Object error) => _fail(error),
      );
    }
  }

  static const String aes256GcmMode = 'aead_aes256_gcm_rtpsize';
  static const String xchacha20Poly1305Mode = 'aead_xchacha20_poly1305_rtpsize';

  final VoiceGatewayTransport _transport;
  final VoiceUdpTransport _udp;
  final DiscordVoiceRtcTransport? _rtcTransport;
  final int _maxDaveProtocolVersion;
  final VoiceHeartbeatScheduler _heartbeatScheduler;
  final VoiceNowMilliseconds _nowMilliseconds;
  final VoiceReconnectDelay _reconnectDelay;
  final GatewayBackoffPolicy _reconnectBackoffPolicy;
  final int _maxReconnectAttempts;
  late final DiscordDaveController _dave;
  final StreamController<DiscordVoiceNetworkState> _states =
      StreamController.broadcast();
  final StreamController<VoiceGatewayBinaryMessage> _binaryMessages =
      StreamController.broadcast();

  DiscordVoiceNetworkState _state = DiscordVoiceNetworkState();
  StreamSubscription<Object?>? _messageSubscription;
  StreamSubscription<int?>? _closeSubscription;
  StreamSubscription<String>? _rtcErrorSubscription;
  VoiceScheduledTask? _heartbeatTask;
  DiscordVoiceCredentials? _credentials;
  DiscordVoiceConnectionOptions _connectionOptions =
      const DiscordVoiceConnectionOptions.audioOnly();
  Future<void>? _reconnectWork;
  _VoiceReconnectMode? _queuedReconnectMode;
  int _reconnectAttempt = 0;
  bool _disposed = false;

  DiscordVoiceNetworkState get state => _state;

  Stream<DiscordVoiceNetworkState> get states async* {
    yield _state;
    yield* _states.stream;
  }

  Stream<VoiceGatewayBinaryMessage> get binaryMessages =>
      _binaryMessages.stream;

  Stream<Uint8List> get udpPackets => _udp.packets;

  bool get usesWebRtc => _connectionOptions.usesWebRtc;

  Stream<DiscordVoiceRtcAudioFrame> get rtcAudioFrames {
    final transport = _rtcTransport;
    if (!_connectionOptions.usesWebRtc ||
        transport is! DiscordVoiceRtcMediaTransport) {
      throw StateError('WebRTC audio transport가 설정되지 않았습니다.');
    }
    return transport.audioFrames;
  }

  Stream<DiscordVoiceRtcVideoFrame> get rtcVideoFrames {
    return _requireRtcMediaTransport().videoFrames;
  }

  Stream<DiscordVoiceRtcVideoStream> get rtcVideoStreams {
    return _requireRtcMediaTransport().videoStreams;
  }

  Future<void> connect(
    DiscordVoiceCredentials credentials, {
    DiscordVoiceConnectionOptions options =
        const DiscordVoiceConnectionOptions.audioOnly(),
  }) async {
    _ensureActive();
    _credentials = null;
    await _resetConnections();
    _dave.resetConnectionState();
    _reconnectAttempt = 0;
    _credentials = credentials;
    _connectionOptions = options;
    _update(
      DiscordVoiceNetworkState(phase: DiscordVoiceNetworkPhase.connecting),
    );
    final endpoint = credentials.endpoint.trim();
    if (endpoint.isEmpty) {
      throw const FormatException('Voice Gateway endpoint가 필요합니다.');
    }
    await _openWebSocket(Uri.parse('wss://$endpoint?v=8'));
    await _identify(credentials);
  }

  Future<void> sendBinary(int opcode, Uint8List payload) async {
    _ensureActive();
    if (opcode < 0 || opcode > 255) {
      throw const FormatException('Voice binary opcode 범위가 올바르지 않습니다.');
    }
    await _transport.sendBinary(Uint8List.fromList([opcode, ...payload]));
  }

  Future<void> sendUdp(Uint8List packet) async {
    _ensureActive();
    if (_connectionOptions.usesWebRtc) {
      throw StateError('WebRTC media session에서는 UDP frame을 직접 보낼 수 없습니다.');
    }
    if (!_hasActiveMediaSession) {
      throw StateError('Voice UDP 연결이 준비되지 않았습니다.');
    }
    await _udp.send(Uint8List.fromList(packet));
  }

  Future<void> sendRtcAudio(
    Uint8List opusFrame, {
    int durationMilliseconds = 20,
  }) async {
    _ensureActive();
    final transport = _rtcTransport;
    if (!_connectionOptions.usesWebRtc ||
        transport is! DiscordVoiceRtcMediaTransport) {
      throw StateError('WebRTC audio transport가 설정되지 않았습니다.');
    }
    if (!_hasActiveMediaSession) {
      throw StateError('WebRTC audio session이 준비되지 않았습니다.');
    }
    await transport.sendAudio(
      Uint8List.fromList(opusFrame),
      durationMilliseconds: durationMilliseconds,
    );
  }

  Future<void> renderRtcVideo(
    Uint8List h264AccessUnit, {
    required int ssrc,
    required int timestamp,
  }) async {
    _ensureActive();
    if (!_hasActiveMediaSession) {
      throw StateError('WebRTC video session이 준비되지 않았습니다.');
    }
    await _requireRtcMediaTransport().renderVideo(
      Uint8List.fromList(h264AccessUnit),
      ssrc: ssrc,
      timestamp: timestamp,
    );
  }

  Future<void> setSpeaking(bool speaking) async {
    final ssrc = _state.ssrc;
    if (_state.phase != DiscordVoiceNetworkPhase.ready || ssrc == null) {
      return;
    }
    await _transport.sendJson({
      'op': 5,
      'd': {'speaking': speaking ? 1 : 0, 'delay': 0, 'ssrc': ssrc},
    });
  }

  Uint8List protectAudio(Uint8List opusFrame) {
    final ssrc = _requireReadySsrc();
    return _dave.encryptAudio(Uint8List.fromList(opusFrame), ssrc: ssrc);
  }

  Uint8List unprotectAudio(
    Uint8List encryptedFrame, {
    required String remoteUserId,
  }) {
    _requireReadySsrc();
    if (int.tryParse(remoteUserId) == null) {
      throw const FormatException('DAVE 원격 사용자 ID가 올바르지 않습니다.');
    }
    return _dave.decryptAudio(
      Uint8List.fromList(encryptedFrame),
      remoteUserId: remoteUserId,
    );
  }

  Uint8List unprotectVideo(
    Uint8List encryptedFrame, {
    required String remoteUserId,
  }) {
    _requireReadySsrc();
    if (int.tryParse(remoteUserId) == null) {
      throw const FormatException('DAVE 원격 video 사용자 ID가 올바르지 않습니다.');
    }
    return _dave.decryptVideo(
      Uint8List.fromList(encryptedFrame),
      remoteUserId: remoteUserId,
    );
  }

  Future<void> disconnect() async {
    _ensureActive();
    _credentials = null;
    _queuedReconnectMode = null;
    await _resetConnections();
    _update(DiscordVoiceNetworkState());
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _credentials = null;
    _queuedReconnectMode = null;
    await _rtcErrorSubscription?.cancel();
    _rtcErrorSubscription = null;
    await _resetConnections();
    _dave.close();
    await _states.close();
    await _binaryMessages.close();
  }

  Future<void> _identify(DiscordVoiceCredentials credentials) async {
    final videoData = _connectionOptions.usesWebRtc
        ? <String, Object?>{
            'video': true,
            'streams': const [
              {'type': 'screen', 'rid': '100', 'quality': 100},
            ],
          }
        : const <String, Object?>{};
    await _transport.sendJson({
      'op': 0,
      'd': {
        'server_id': credentials.guildId,
        'user_id': credentials.userId,
        'session_id': credentials.sessionId,
        'token': credentials.token,
        ...videoData,
        'max_dave_protocol_version': _maxDaveProtocolVersion,
      },
    });
    _update(_state.copyWith(phase: DiscordVoiceNetworkPhase.identifying));
  }

  void _fail(Object error) {
    if (_disposed) {
      return;
    }
    final message = error is FormatException
        ? error.message
        : error.toString().replaceFirst('Bad state: ', '');
    _update(
      _state.copyWith(
        phase: DiscordVoiceNetworkPhase.failed,
        errorMessage: message,
      ),
    );
  }

  Future<void> _resetConnections() async {
    _heartbeatTask?.cancel();
    _heartbeatTask = null;
    await _closeWebSocket();
    await _udp.close();
    await _rtcTransport?.close();
  }

  Future<void> _closeWebSocket() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _closeSubscription?.cancel();
    _closeSubscription = null;
    await _transport.close();
  }

  Future<void> _openWebSocket(Uri uri) async {
    _messageSubscription = _transport.messages.listen(
      (message) => unawaited(_receive(message)),
      onError: _handleTransportError,
    );
    _closeSubscription = _transport.closes.listen(_handleClose);
    await _transport.connect(uri);
  }

  void _update(DiscordVoiceNetworkState nextState) {
    _state = nextState;
    if (!_states.isClosed) {
      _states.add(nextState);
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('이미 종료된 Voice Gateway client입니다.');
    }
  }

  int _requireReadySsrc() {
    _ensureActive();
    final ssrc = _state.ssrc;
    if (!_hasActiveMediaSession || ssrc == null) {
      throw StateError('Voice media session이 준비되지 않았습니다.');
    }
    return ssrc;
  }

  DiscordVoiceRtcMediaTransport _requireRtcMediaTransport() {
    final transport = _rtcTransport;
    if (!_connectionOptions.usesWebRtc ||
        transport is! DiscordVoiceRtcMediaTransport) {
      throw StateError('WebRTC video transport가 설정되지 않았습니다.');
    }
    return transport;
  }

  bool get _hasActiveMediaSession {
    return _state.phase == DiscordVoiceNetworkPhase.ready ||
        _state.phase == DiscordVoiceNetworkPhase.resuming;
  }
}

Future<void> _defaultVoiceReconnectDelay(Duration delay) {
  return Future<void>.delayed(delay);
}
