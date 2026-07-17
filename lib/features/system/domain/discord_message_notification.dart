final class DiscordMessageNotification {
  const DiscordMessageNotification({
    required this.channelId,
    required this.title,
    required this.body,
  });

  static DiscordMessageNotification? fromGatewayEvent(
    Map<String, Object?> event, {
    required String? currentUserId,
    required String? selectedChannelId,
  }) {
    final data = event['d'];
    if (event['op'] != 0 || event['t'] != 'MESSAGE_CREATE' || data is! Map) {
      return null;
    }
    final channelId = data['channel_id'];
    final author = data['author'];
    if (channelId is! String || author is! Map) {
      return null;
    }
    final authorId = author['id'];
    if (channelId == selectedChannelId || authorId == currentUserId) {
      return null;
    }
    final username = author['username'];
    if (authorId is! String || username is! String) {
      return null;
    }
    final globalName = author['global_name'];
    final title = globalName is String && globalName.trim().isNotEmpty
        ? globalName.trim()
        : username.trim();
    final content = data['content'];
    final text = content is String ? content.trim() : '';
    final attachments = data['attachments'];
    final body = text.isNotEmpty
        ? text
        : attachments is List && attachments.isNotEmpty
        ? '첨부 파일을 보냈습니다.'
        : '새 메시지가 도착했습니다.';
    return DiscordMessageNotification(
      channelId: channelId,
      title: _limit(title, 80),
      body: _limit(body, 240),
    );
  }

  final String channelId;
  final String title;
  final String body;
}

String _limit(String value, int maxLength) {
  if (value.length <= maxLength) {
    return value;
  }
  return '${value.substring(0, maxLength - 1)}…';
}
