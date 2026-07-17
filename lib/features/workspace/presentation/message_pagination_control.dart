import 'package:flutter/material.dart';

typedef LoadOlderMessagesCallback = Future<void> Function();

class OlderMessagesControl extends StatelessWidget {
  const OlderMessagesControl({
    required this.isLoading,
    required this.errorMessage,
    required this.onLoad,
    super.key,
  });

  final bool isLoading;
  final String? errorMessage;
  final LoadOlderMessagesCallback? onLoad;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          if (errorMessage case final message?)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFFF23F42)),
              ),
            ),
          TextButton.icon(
            onPressed: isLoading || onLoad == null ? null : onLoad,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.history),
            label: Text(isLoading ? '불러오는 중' : '이전 메시지 불러오기'),
          ),
        ],
      ),
    );
  }
}
