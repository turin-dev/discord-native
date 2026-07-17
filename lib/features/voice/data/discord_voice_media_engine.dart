import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:discord_native/features/voice/data/discord_opus_codec.dart';
import 'package:discord_native/features/voice/data/discord_pcm_frame_assembler.dart';
import 'package:discord_native/features/voice/data/discord_voice_input_gate.dart';
import 'package:discord_native/features/voice/data/discord_voice_media_connection.dart';
import 'package:discord_native/features/voice/data/discord_voice_media_network.dart';
import 'package:discord_native/features/voice/data/discord_voice_rtp_codec.dart';
import 'package:discord_native/features/voice/data/discord_voice_rtc_transport.dart';
import 'package:discord_native/features/voice/data/record_discord_microphone_capture.dart';
import 'package:discord_native/features/voice/data/soloud_discord_voice_playback.dart';
import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';

export 'package:discord_native/features/voice/data/discord_voice_media_network.dart';
export 'package:discord_native/features/voice/data/discord_voice_media_connection.dart';
export 'package:discord_native/features/voice/data/discord_voice_rtc_transport.dart';
export 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';

part 'discord_voice_media_engine_receive.dart';
part 'discord_voice_media_engine_send.dart';

final class DiscordVoiceMediaEngine implements DiscordVoiceMediaConnection {
  DiscordVoiceMediaEngine({
    required DiscordVoiceMediaNetwork network,
    required DiscordMicrophoneCapture microphone,
    required DiscordOpusCodec opus,
    required DiscordVoicePlayback playback,
    DiscordPcmFrameAssembler? frameAssembler,
    DiscordVoiceInputGate? inputGate,
    bool captureInput = true,
    int initialSequence = 0,
    int initialTimestamp = 0,
    int initialNonce = 0,
  }) : _network = network,
       _microphone = microphone,
       _opus = opus,
       _playback = playback,
       _frameAssembler = frameAssembler ?? DiscordPcmFrameAssembler(),
       _inputGate = inputGate ?? DiscordVoiceInputGate(),
       _captureInput = captureInput,
       _sequence = _validatedCounter(initialSequence, 0xFFFF, 'RTP sequence'),
       _timestamp = _validatedCounter(
         initialTimestamp,
         0xFFFFFFFF,
         'RTP timestamp',
       ),
       _nonce = _validatedCounter(initialNonce, 0xFFFFFFFF, 'RTP nonce');

  final DiscordVoiceMediaNetwork _network;
  final DiscordMicrophoneCapture _microphone;
  final DiscordOpusCodec _opus;
  final DiscordVoicePlayback _playback;
  final DiscordPcmFrameAssembler _frameAssembler;
  final DiscordVoiceInputGate _inputGate;
  final bool _captureInput;
  final StreamController<DiscordVoiceMediaState> _states =
      StreamController.broadcast();

  DiscordVoiceMediaState _state = const DiscordVoiceMediaState();
  DiscordVoiceRtpCodec? _rtp;
  StreamSubscription<Uint8List>? _microphoneSubscription;
  StreamSubscription<Uint8List>? _udpSubscription;
  StreamSubscription<DiscordVoiceRtcAudioFrame>? _rtcSubscription;
  StreamSubscription<DiscordVoiceRtcVideoFrame>? _rtcVideoSubscription;
  StreamSubscription<DiscordVoiceRtcVideoStream>? _rtcVideoStreamSubscription;
  StreamSubscription<Map<int, String>>? _usersSubscription;
  StreamSubscription<Map<int, String>>? _videoUsersSubscription;
  Future<void> _sendWork = Future.value();
  Future<void> _receiveWork = Future.value();
  Future<void> _userWork = Future.value();
  Future<void> _videoWork = Future.value();
  Map<int, String> _usersBySsrc = const {};
  Map<int, String> _videoUsersBySsrc = const {};
  Map<int, Object> _videoPreviewsBySsrc = const {};
  Map<int, List<DiscordVoiceRtcVideoFrame>> _pendingVideoFramesBySsrc =
      const {};
  Map<String, int> _lastSequenceByUser = const {};
  int _sequence;
  int _timestamp;
  int _nonce;
  bool _disposed = false;

  @override
  DiscordVoiceMediaState get state => _state;

  @override
  Stream<DiscordVoiceMediaState> get states async* {
    yield _state;
    yield* _states.stream;
  }

  @override
  Future<void> start() async {
    _ensureActive();
    if (_state.phase != DiscordVoiceMediaPhase.idle) {
      throw StateError('Voice media engine이 이미 시작되었습니다.');
    }
    _update(_state.copyWith(phase: DiscordVoiceMediaPhase.starting));
    try {
      final session = _network.session;
      _rtp = session.usesWebRtc
          ? null
          : DiscordVoiceRtpCodec(
              mode: session.encryptionMode,
              secretKey: session.secretKey,
            );
      _usersBySsrc = Map.unmodifiable(_network.usersBySsrc);
      _videoUsersBySsrc = Map.unmodifiable(_network.videoUsersBySsrc);
      await _playback.initialize();
      _listenToNetwork(usesWebRtc: session.usesWebRtc);
      _update(
        _state.copyWith(
          phase: DiscordVoiceMediaPhase.active,
          errorMessage: null,
        ),
      );
      if (_captureInput && !_state.muted) {
        await _startMicrophone();
      }
    } on Object catch (error) {
      await _cancelSubscriptions();
      _fail(error);
      rethrow;
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    _ensureActive();
    if (_state.muted == muted) {
      return;
    }
    _update(_state.copyWith(muted: muted));
    if (_state.phase != DiscordVoiceMediaPhase.active) {
      return;
    }
    try {
      if (muted) {
        await _stopMicrophone();
        await _sendWork;
        await _stopSpeaking();
      } else {
        await _startMicrophone();
      }
    } on Object catch (error) {
      _reportError(error);
      rethrow;
    }
  }

  @override
  Future<void> setDeafened(bool deafened) async {
    _ensureActive();
    if (_state.deafened == deafened) {
      return;
    }
    _update(_state.copyWith(deafened: deafened));
    if (deafened) {
      for (final userId in _usersBySsrc.values.toSet()) {
        await _playback.removeUser(userId);
      }
    }
  }

  @override
  Future<void> setInputMode(DiscordVoiceInputMode inputMode) async {
    _ensureActive();
    if (_state.inputMode == inputMode) {
      return;
    }
    await _sendWork;
    await _stopSpeaking();
    _inputGate.reset();
    _update(_state.copyWith(inputMode: inputMode, pushToTalkPressed: false));
  }

  @override
  Future<void> setPushToTalkPressed(bool pressed) async {
    _ensureActive();
    if (_state.inputMode != DiscordVoiceInputMode.pushToTalk) {
      throw StateError('Push-to-talk 입력 모드가 아닙니다.');
    }
    if (_state.pushToTalkPressed == pressed) {
      return;
    }
    _update(_state.copyWith(pushToTalkPressed: pressed));
    if (!pressed) {
      await _sendWork;
      await _stopSpeaking();
    }
  }

  @override
  void setUserVolume(String remoteUserId, double volume) {
    _ensureActive();
    if (_state.phase != DiscordVoiceMediaPhase.active) {
      throw StateError('Voice media engine이 활성 상태가 아닙니다.');
    }
    _playback.setUserVolume(remoteUserId, volume);
  }

  Future<void> waitForPendingWork() async {
    for (var iteration = 0; iteration < 2; iteration += 1) {
      await Future<void>.delayed(Duration.zero);
      await Future.wait([_sendWork, _receiveWork, _userWork, _videoWork]);
    }
  }

  @override
  Future<void> stop() async {
    if (_state.phase == DiscordVoiceMediaPhase.idle || _disposed) {
      return;
    }
    _update(_state.copyWith(phase: DiscordVoiceMediaPhase.stopping));
    await _stopMicrophone();
    await _sendWork;
    await _stopSpeaking(bestEffort: true);
    await _cancelSubscriptions();
    await waitForPendingWork();
    _frameAssembler.reset();
    _inputGate.reset();
    _rtp = null;
    _usersBySsrc = const {};
    _videoUsersBySsrc = const {};
    _videoPreviewsBySsrc = const {};
    _pendingVideoFramesBySsrc = const {};
    _lastSequenceByUser = const {};
    _update(
      _state.copyWith(
        phase: DiscordVoiceMediaPhase.idle,
        speaking: false,
        pushToTalkPressed: false,
        remoteVideoPreviews: const {},
        errorMessage: null,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    await stop();
    Object? disposalError;
    try {
      await _microphone.dispose();
    } on Object catch (error) {
      disposalError ??= error;
    }
    try {
      await _playback.dispose();
    } on Object catch (error) {
      disposalError ??= error;
    }
    _opus.close();
    _disposed = true;
    await _states.close();
    if (disposalError != null) {
      throw StateError('Voice media resource를 정리하지 못했습니다: $disposalError');
    }
  }

  void _listenToNetwork({required bool usesWebRtc}) {
    if (usesWebRtc) {
      _rtcSubscription = _network.rtcAudioFrames.listen(
        (frame) =>
            _receiveWork = _queue(_receiveWork, () => _receiveRtcAudio(frame)),
        onError: _reportError,
      );
      _rtcVideoSubscription = _network.rtcVideoFrames.listen(
        (frame) =>
            _videoWork = _queue(_videoWork, () => _receiveRtcVideo(frame)),
        onError: _reportError,
      );
      _rtcVideoStreamSubscription = _network.rtcVideoStreams.listen(
        (stream) => _videoWork = _queue(
          _videoWork,
          () async => _receiveRtcVideoStream(stream),
        ),
        onError: _reportError,
      );
    } else {
      _udpSubscription = _network.udpPackets.listen(
        (packet) =>
            _receiveWork = _queue(_receiveWork, () => _receivePacket(packet)),
        onError: _reportError,
      );
    }
    _usersSubscription = _network.usersBySsrcChanges.listen(
      (users) => _userWork = _queue(_userWork, () => _replaceUsers(users)),
      onError: _reportError,
    );
    _videoUsersSubscription = _network.videoUsersBySsrcChanges.listen(
      (users) =>
          _videoWork = _queue(_videoWork, () => _replaceVideoUsers(users)),
      onError: _reportError,
    );
  }

  Future<void> _startMicrophone() async {
    if (!_captureInput) {
      return;
    }
    if (_microphoneSubscription != null || _microphone.isCapturing) {
      return;
    }
    final stream = await _microphone.start();
    _microphoneSubscription = stream.listen(
      (chunk) => _sendWork = _queue(_sendWork, () => _sendPcmChunk(chunk)),
      onError: _reportError,
    );
  }

  Future<void> _stopMicrophone() async {
    await _microphoneSubscription?.cancel();
    _microphoneSubscription = null;
    if (_microphone.isCapturing) {
      await _microphone.stop();
    }
    _frameAssembler.reset();
    _inputGate.reset();
  }

  Future<void> _cancelSubscriptions() async {
    await _udpSubscription?.cancel();
    _udpSubscription = null;
    await _rtcSubscription?.cancel();
    _rtcSubscription = null;
    await _rtcVideoSubscription?.cancel();
    _rtcVideoSubscription = null;
    await _rtcVideoStreamSubscription?.cancel();
    _rtcVideoStreamSubscription = null;
    await _usersSubscription?.cancel();
    _usersSubscription = null;
    await _videoUsersSubscription?.cancel();
    _videoUsersSubscription = null;
  }

  Future<void> _queue(Future<void> current, Future<void> Function() operation) {
    return current.then((_) => operation()).catchError((Object error) {
      _reportError(error);
    });
  }

  void _reportError(Object error) {
    if (!_disposed) {
      _update(_state.copyWith(errorMessage: _errorMessage(error)));
    }
  }

  void _fail(Object error) {
    _update(
      _state.copyWith(
        phase: DiscordVoiceMediaPhase.failed,
        errorMessage: _errorMessage(error),
      ),
    );
  }

  void _update(DiscordVoiceMediaState nextState) {
    _state = nextState;
    if (!_states.isClosed) {
      _states.add(nextState);
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('이미 종료된 Voice media engine입니다.');
    }
  }
}

int _validatedCounter(int value, int maximum, String field) {
  if (value < 0 || value > maximum) {
    throw FormatException('$field 범위가 올바르지 않습니다.');
  }
  return value;
}

bool _isOpusRtp(Uint8List packet) {
  return packet.length >= 2 && packet[0] >> 6 == 2 && packet[1] & 0x7F == 0x78;
}

String _errorMessage(Object error) {
  return error is FormatException
      ? error.message
      : error.toString().replaceFirst('Bad state: ', '');
}

final Uint8List _silenceFrame = Uint8List.fromList([0xF8, 0xFF, 0xFE]);
