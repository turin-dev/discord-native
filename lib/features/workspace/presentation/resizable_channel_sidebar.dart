import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

class ResizableChannelSidebar extends StatelessWidget {
  const ResizableChannelSidebar({
    required this.width,
    required this.child,
    required this.onDrag,
    required this.onDragEnd,
    this.resizable = true,
    super.key,
  });

  final double width;
  final Widget child;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;
  final bool resizable;

  @override
  Widget build(BuildContext context) {
    if (!resizable) {
      return SizedBox(width: width, child: child);
    }
    return SizedBox(
      width: width + 8,
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            width: 8,
            child: Listener(
              key: const ValueKey('channel-sidebar-resize-handle'),
              behavior: HitTestBehavior.opaque,
              onPointerMove: (event) => onDrag(event.delta.dx),
              onPointerUp: (_) => onDragEnd(),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: ColoredBox(color: context.discordPalette.divider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
