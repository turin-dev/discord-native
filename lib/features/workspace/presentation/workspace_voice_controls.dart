import 'dart:async';

import 'package:discord_native/features/voice/domain/discord_voice_media_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_state.dart';
import 'package:discord_native/features/voice/domain/discord_voice_ui_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/video/domain/discord_video_ui_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

final class VoiceChannelTile extends StatelessWidget {
  const VoiceChannelTile({
    required this.channel,
    required this.active,
    required this.participants,
    required this.participantNames,
    required this.onJoin,
    this.onSetUserVolume,
    this.watchingStreamKey,
    this.onWatchStream,
    this.onStopWatchingStream,
    super.key,
  });

  final DiscordChannel channel;
  final bool active;
  final List<DiscordVoiceParticipant> participants;
  final Map<String, String> participantNames;
  final ValueChanged<String> onJoin;
  final void Function(String userId, double volume)? onSetUserVolume;
  final String? watchingStreamKey;
  final ValueChanged<String>? onWatchStream;
  final VoidCallback? onStopWatchingStream;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: ValueKey('voice-channel-${channel.id}'),
          dense: true,
          selected: active,
          selectedTileColor: const Color(0xFF404249),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          contentPadding: const EdgeInsets.only(left: 12, right: 8),
          leading: Icon(
            active ? Icons.volume_up : Icons.volume_up_outlined,
            color: active ? const Color(0xFF23A55A) : const Color(0xFF949BA4),
          ),
          title: Text(
            channel.name,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFFB5BAC1),
            ),
          ),
          onTap: () => onJoin(channel.id),
        ),
        for (final participant in participants)
          _VoiceParticipantRow(
            participant: participant,
            name: participantNames[participant.userId] ?? participant.userId,
            onSetVolume: onSetUserVolume,
            streamKey: _participantStreamKey(participant),
            watchingStreamKey: watchingStreamKey,
            onWatchStream: onWatchStream,
            onStopWatchingStream: onStopWatchingStream,
          ),
      ],
    );
  }
}

final class _VoiceParticipantRow extends StatelessWidget {
  const _VoiceParticipantRow({
    required this.participant,
    required this.name,
    this.onSetVolume,
    this.streamKey,
    this.watchingStreamKey,
    this.onWatchStream,
    this.onStopWatchingStream,
  });

  final DiscordVoiceParticipant participant;
  final String name;
  final void Function(String userId, double volume)? onSetVolume;
  final String? streamKey;
  final String? watchingStreamKey;
  final ValueChanged<String>? onWatchStream;
  final VoidCallback? onStopWatchingStream;

  @override
  Widget build(BuildContext context) {
    final muted = participant.mute || participant.selfMute;
    final deafened = participant.deaf || participant.selfDeaf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 3, 12, 3),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 9,
            backgroundColor: Color(0xFF5865F2),
            child: Icon(Icons.person, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 12),
            ),
          ),
          if (muted)
            const Icon(Icons.mic_off, size: 14, color: Color(0xFFF23F42)),
          if (deafened)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(
                Icons.headset_off,
                size: 14,
                color: Color(0xFFF23F42),
              ),
            ),
          if (participant.selfStream &&
              streamKey != null &&
              onWatchStream != null)
            IconButton(
              key: ValueKey('voice-watch-stream-${participant.userId}'),
              tooltip: watchingStreamKey == streamKey
                  ? 'Go Live 시청 중지'
                  : 'Go Live 시청',
              visualDensity: VisualDensity.compact,
              onPressed: watchingStreamKey == streamKey
                  ? onStopWatchingStream
                  : () => onWatchStream!(streamKey!),
              icon: Icon(
                watchingStreamKey == streamKey
                    ? Icons.stop_screen_share_outlined
                    : Icons.live_tv_outlined,
                size: 16,
                color: const Color(0xFF23A55A),
              ),
            ),
          if (onSetVolume != null)
            PopupMenuButton<double>(
              key: ValueKey('voice-volume-${participant.userId}'),
              tooltip: '$name 사용자 음량',
              onSelected: (volume) => onSetVolume!(participant.userId, volume),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 0, child: Text('음소거')),
                PopupMenuItem(value: 0.5, child: Text('50%')),
                PopupMenuItem(value: 1, child: Text('100%')),
                PopupMenuItem(value: 1.5, child: Text('150%')),
                PopupMenuItem(value: 2, child: Text('200%')),
              ],
              icon: const Icon(
                Icons.volume_up,
                size: 14,
                color: Color(0xFFB5BAC1),
              ),
            ),
        ],
      ),
    );
  }
}

final class VoiceConnectionPanel extends StatelessWidget {
  const VoiceConnectionPanel({
    required this.state,
    required this.channelName,
    required this.onSetMuted,
    required this.onSetDeafened,
    required this.onSetInputMode,
    required this.onPushToTalkPressed,
    required this.onSetCameraEnabled,
    required this.onLeave,
    this.onSetScreenShareEnabled,
    this.onSetScreenSharePaused,
    this.localVideoStream,
    this.localScreenStream,
    super.key,
  });

  final DiscordVoiceUiState state;
  final String channelName;
  final ValueChanged<bool> onSetMuted;
  final ValueChanged<bool> onSetDeafened;
  final ValueChanged<DiscordVoiceInputMode> onSetInputMode;
  final ValueChanged<bool> onPushToTalkPressed;
  final ValueChanged<bool> onSetCameraEnabled;
  final ValueChanged<bool>? onSetScreenShareEnabled;
  final ValueChanged<bool>? onSetScreenSharePaused;
  final VoidCallback onLeave;
  final MediaStream? localVideoStream;
  final MediaStream? localScreenStream;

  @override
  Widget build(BuildContext context) {
    final voice = state.voice;
    return ColoredBox(
      color: const Color(0xFF232428),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _connectionLabel(state),
              style: TextStyle(
                color: state.errorMessage == null
                    ? const Color(0xFF23A55A)
                    : const Color(0xFFF23F42),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              channelName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFB5BAC1), fontSize: 11),
            ),
            if (state.errorMessage case final error?)
              Text(
                error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFF23F42), fontSize: 10),
              ),
            if (localVideoStream != null && state.video.cameraEnabled)
              _LocalVideoPreview(stream: localVideoStream!),
            if (localScreenStream != null &&
                state.video.screenSharePhase != DiscordVideoPhase.idle)
              _LocalVideoPreview(
                stream: localScreenStream!,
                mirror: false,
                label: '내 화면',
                previewKey: const ValueKey('voice-screen-preview'),
              ),
            for (final entry in state.video.remotePreviews.entries)
              if (entry.value is MediaStream)
                _LocalVideoPreview(
                  key: ValueKey('voice-remote-video-${entry.key}'),
                  stream: entry.value as MediaStream,
                  mirror: false,
                  label: entry.key,
                ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                IconButton(
                  key: const ValueKey('voice-camera-button'),
                  tooltip: state.video.cameraEnabled ? '카메라 끄기' : '카메라 켜기',
                  onPressed:
                      state.video.phase == DiscordVideoPhase.starting ||
                          state.video.phase == DiscordVideoPhase.stopping
                      ? null
                      : () => onSetCameraEnabled(!state.video.cameraEnabled),
                  color: state.video.cameraEnabled
                      ? const Color(0xFF23A55A)
                      : null,
                  icon: Icon(
                    state.video.cameraEnabled
                        ? Icons.videocam
                        : Icons.videocam_off_outlined,
                  ),
                ),
                IconButton(
                  key: const ValueKey('voice-screen-share-button'),
                  tooltip: state.video.screenShareEnabled
                      ? '화면 공유 중지'
                      : '화면 공유 시작',
                  onPressed:
                      onSetScreenShareEnabled == null ||
                          state.video.screenSharePhase ==
                              DiscordVideoPhase.starting ||
                          state.video.screenSharePhase ==
                              DiscordVideoPhase.stopping
                      ? null
                      : () => onSetScreenShareEnabled!(
                          !state.video.screenShareEnabled,
                        ),
                  color: state.video.screenShareEnabled
                      ? const Color(0xFF23A55A)
                      : null,
                  icon: Icon(
                    state.video.screenShareEnabled
                        ? Icons.screen_share
                        : Icons.stop_screen_share_outlined,
                  ),
                ),
                if (state.video.screenShareEnabled)
                  IconButton(
                    key: const ValueKey('voice-screen-pause-button'),
                    tooltip: state.video.screenPaused
                        ? '화면 공유 재개'
                        : '화면 공유 일시 정지',
                    onPressed: onSetScreenSharePaused == null
                        ? null
                        : () => onSetScreenSharePaused!(
                            !state.video.screenPaused,
                          ),
                    icon: Icon(
                      state.video.screenPaused ? Icons.play_arrow : Icons.pause,
                    ),
                  ),
                IconButton(
                  key: const ValueKey('voice-mute-button'),
                  tooltip: voice.selfMute ? '음소거 해제' : '음소거',
                  onPressed: () => onSetMuted(!voice.selfMute),
                  icon: Icon(voice.selfMute ? Icons.mic_off : Icons.mic),
                ),
                IconButton(
                  key: const ValueKey('voice-deafen-button'),
                  tooltip: voice.selfDeaf ? '헤드셋 켜기' : '헤드셋 끄기',
                  onPressed: () => onSetDeafened(!voice.selfDeaf),
                  icon: Icon(
                    voice.selfDeaf ? Icons.headset_off : Icons.headphones,
                  ),
                ),
                IconButton(
                  key: const ValueKey('voice-input-mode-button'),
                  tooltip:
                      state.media.inputMode ==
                          DiscordVoiceInputMode.voiceActivity
                      ? '푸시투토크로 전환'
                      : '입력 감지로 전환',
                  onPressed: () => onSetInputMode(
                    state.media.inputMode == DiscordVoiceInputMode.voiceActivity
                        ? DiscordVoiceInputMode.pushToTalk
                        : DiscordVoiceInputMode.voiceActivity,
                  ),
                  icon: Icon(
                    state.media.inputMode == DiscordVoiceInputMode.pushToTalk
                        ? Icons.keyboard_voice
                        : Icons.graphic_eq,
                  ),
                ),
                IconButton(
                  key: const ValueKey('voice-leave-button'),
                  tooltip: '음성 연결 끊기',
                  onPressed: onLeave,
                  color: const Color(0xFFF23F42),
                  icon: const Icon(Icons.call_end),
                ),
              ],
            ),
            if (state.media.inputMode == DiscordVoiceInputMode.pushToTalk)
              Listener(
                key: const ValueKey('voice-ptt-button'),
                onPointerDown: (_) => onPushToTalkPressed(true),
                onPointerUp: (_) => onPushToTalkPressed(false),
                onPointerCancel: (_) => onPushToTalkPressed(false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: state.media.pushToTalkPressed
                        ? const Color(0xFF23A55A)
                        : const Color(0xFF404249),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('눌러서 말하기'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _LocalVideoPreview extends StatefulWidget {
  const _LocalVideoPreview({
    required this.stream,
    this.mirror = true,
    this.label,
    this.previewKey,
    super.key,
  });

  final MediaStream stream;
  final bool mirror;
  final String? label;
  final Key? previewKey;

  @override
  State<_LocalVideoPreview> createState() => _LocalVideoPreviewState();
}

final class _LocalVideoPreviewState extends State<_LocalVideoPreview> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();
  String? _errorMessage;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeRenderer());
  }

  @override
  void didUpdateWidget(covariant _LocalVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_initialized && oldWidget.stream.id != widget.stream.id) {
      _renderer.srcObject = widget.stream;
    }
  }

  Future<void> _initializeRenderer() async {
    try {
      await _renderer.initialize();
      _initialized = true;
      if (!mounted) {
        await _renderer.dispose();
        return;
      }
      _renderer.srcObject = widget.stream;
      setState(() {});
    } on Object catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _videoPreviewError(error));
      }
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _renderer.srcObject = null;
      unawaited(_renderer.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;
    return Container(
      key:
          widget.previewKey ??
          (widget.mirror
              ? const ValueKey('voice-camera-preview')
              : ValueKey('voice-remote-video-preview-${widget.label}')),
      height: 120,
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(6),
      ),
      child: errorMessage == null
          ? Stack(
              fit: StackFit.expand,
              children: [
                RTCVideoView(_renderer, mirror: widget.mirror),
                if (widget.label case final label?)
                  Positioned(
                    left: 6,
                    bottom: 4,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        shadows: [Shadow(blurRadius: 3)],
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFF23F42), fontSize: 11),
              ),
            ),
    );
  }
}

String _participantStreamKey(DiscordVoiceParticipant participant) {
  return 'guild:${participant.guildId}:${participant.channelId}:${participant.userId}';
}

String _videoPreviewError(Object error) {
  return error is FormatException ? error.message : '카메라 미리보기를 표시할 수 없습니다.';
}

String _connectionLabel(DiscordVoiceUiState state) {
  return switch (state.voice.phase) {
    DiscordVoicePhase.ready => '음성 연결됨',
    DiscordVoicePhase.failed => '음성 연결 실패',
    DiscordVoicePhase.disconnecting => '음성 연결 종료 중',
    _ => '음성 연결 중',
  };
}
