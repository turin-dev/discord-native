import 'dart:async';

import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

Widget buildDiscordAttachmentVideoPlayer(DiscordAttachment attachment) {
  return DiscordAttachmentVideoPlayer(
    key: ValueKey('attachment-video-${attachment.id}'),
    attachment: attachment,
  );
}

class DiscordAttachmentVideoPlayer extends StatefulWidget {
  const DiscordAttachmentVideoPlayer({required this.attachment, super.key});

  final DiscordAttachment attachment;

  @override
  State<DiscordAttachmentVideoPlayer> createState() =>
      _DiscordAttachmentVideoPlayerState();
}

class _DiscordAttachmentVideoPlayerState
    extends State<DiscordAttachmentVideoPlayer> {
  VideoPlayerController? _controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    final uri = Uri.tryParse(widget.attachment.proxyUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('영상 URL은 HTTPS여야 합니다.');
    }
    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: const {'Accept': '*/*', 'Range': 'bytes=0-'},
    );
    _controller = controller;
    await controller.initialize();
  }

  @override
  void dispose() {
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: discordAttachmentAspectRatio(widget.attachment),
      child: ColoredBox(
        color: Colors.black,
        child: FutureBuilder<void>(
          future: _initialization,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _VideoError();
            }
            final controller = _controller;
            if (snapshot.connectionState != ConnectionState.done ||
                controller == null ||
                !controller.value.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }
            return _VideoSurface(controller: controller);
          },
        ),
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  const _VideoSurface({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value.hasError) {
          return const _VideoError();
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Center(child: VideoPlayer(controller)),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _togglePlayback(controller, value),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _VideoControls(controller: controller, value: value),
            ),
            if (value.isBuffering)
              const Center(child: CircularProgressIndicator()),
          ],
        );
      },
    );
  }
}

class _VideoControls extends StatelessWidget {
  const _VideoControls({required this.controller, required this.value});

  final VideoPlayerController controller;
  final VideoPlayerValue value;

  @override
  Widget build(BuildContext context) {
    final duration = value.duration.inMilliseconds.toDouble();
    final position = value.position.inMilliseconds.clamp(
      0,
      value.duration.inMilliseconds,
    );
    return ColoredBox(
      color: const Color(0x99000000),
      child: Row(
        children: [
          IconButton(
            tooltip: value.isPlaying ? '일시정지' : '재생',
            onPressed: () => _togglePlayback(controller, value),
            icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
          ),
          Expanded(
            child: Slider(
              value: duration == 0 ? 0 : position.toDouble(),
              max: duration == 0 ? 1 : duration,
              onChanged: duration == 0
                  ? null
                  : (next) =>
                        controller.seekTo(Duration(milliseconds: next.round())),
            ),
          ),
          IconButton(
            tooltip: value.volume == 0 ? '음소거 해제' : '음소거',
            onPressed: () => controller.setVolume(value.volume == 0 ? 1 : 0),
            icon: Icon(value.volume == 0 ? Icons.volume_off : Icons.volume_up),
          ),
          IconButton(
            tooltip: '전체 화면',
            onPressed: () => _showFullscreen(context, controller),
            icon: const Icon(Icons.fullscreen),
          ),
        ],
      ),
    );
  }
}

class _VideoError extends StatelessWidget {
  const _VideoError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Color(0xFFF23F42)),
          SizedBox(height: 8),
          Text('영상을 재생할 수 없습니다.', style: TextStyle(color: Color(0xFFDBDEE1))),
        ],
      ),
    );
  }
}

Future<void> _togglePlayback(
  VideoPlayerController controller,
  VideoPlayerValue value,
) async {
  if (value.isPlaying) {
    await controller.pause();
  } else {
    await controller.play();
  }
}

Future<void> _showFullscreen(
  BuildContext context,
  VideoPlayerController controller,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton.filledTonal(
              tooltip: '전체 화면 닫기',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    ),
  );
}

double discordAttachmentAspectRatio(DiscordAttachment attachment) {
  final width = attachment.width;
  final height = attachment.height;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 16 / 9;
  }
  return (width / height).clamp(0.5, 2.4);
}
