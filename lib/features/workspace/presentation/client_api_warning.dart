import 'package:discord_native/features/workspace/presentation/discord_design_tokens.dart';
import 'package:flutter/material.dart';

class ClientApiWarning extends StatelessWidget {
  const ClientApiWarning({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('client-api-warning'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: context.discordPalette.warning.withValues(alpha: 0.18),
      child: Text(
        message,
        style: TextStyle(
          color: context.discordPalette.textNormal,
          fontSize: 12,
        ),
      ),
    );
  }
}
