import 'package:discord_native/core/network/discord_rest_client.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';

enum DiscordGuildChannelType {
  text(0),
  voice(2),
  category(4),
  announcement(5),
  forum(15),
  media(16);

  const DiscordGuildChannelType(this.value);

  final int value;

  bool get supportsTextSettings =>
      const {text, announcement, forum, media}.contains(this);

  bool get supportsTags => const {forum, media}.contains(this);
}

final class DiscordForumTagDraft {
  const DiscordForumTagDraft({
    required this.name,
    this.moderated = false,
    this.emojiId,
    this.emojiName,
  });

  final String name;
  final bool moderated;
  final String? emojiId;
  final String? emojiName;
}

final class DiscordCreateChannelRequest {
  const DiscordCreateChannelRequest({
    required this.name,
    required this.type,
    this.topic,
    this.parentId,
    this.slowmodeSeconds = 0,
    this.nsfw = false,
    this.availableTags = const [],
  });

  final String name;
  final DiscordGuildChannelType type;
  final String? topic;
  final String? parentId;
  final int slowmodeSeconds;
  final bool nsfw;
  final List<DiscordForumTagDraft> availableTags;
}

final class DiscordUpdateChannelRequest {
  const DiscordUpdateChannelRequest({
    this.name,
    this.topic,
    this.clearTopic = false,
    this.parentId,
    this.nsfw,
    this.slowmodeSeconds,
  });

  final String? name;
  final String? topic;
  final bool clearTopic;
  final String? parentId;
  final bool? nsfw;
  final int? slowmodeSeconds;
}

abstract interface class ChannelManagementRepository {
  Future<DiscordChannel> createChannel({
    required String guildId,
    required DiscordCreateChannelRequest request,
  });

  Future<DiscordChannel> updateChannel({
    required String channelId,
    required String guildId,
    required DiscordUpdateChannelRequest request,
  });

  Future<void> deleteChannel(String channelId);
}

final class InvalidGuildChannelException implements Exception {
  const InvalidGuildChannelException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class DiscordChannelManagementRepository
    implements ChannelManagementRepository {
  const DiscordChannelManagementRepository(this._api);

  final DiscordRestApi _api;

  @override
  Future<DiscordChannel> createChannel({
    required String guildId,
    required DiscordCreateChannelRequest request,
  }) async {
    final normalizedGuildId = _requiredId(guildId, 'guild ID');
    final payload = _createPayload(request);
    final response = await _api.post(
      '/guilds/$normalizedGuildId/channels',
      data: payload,
    );
    return DiscordChannel.fromJson(
      _readMap(response, 'channel create response'),
      fallbackGuildId: normalizedGuildId,
    );
  }

  @override
  Future<DiscordChannel> updateChannel({
    required String channelId,
    required String guildId,
    required DiscordUpdateChannelRequest request,
  }) async {
    final normalizedChannelId = _requiredId(channelId, 'channel ID');
    final normalizedGuildId = _requiredId(guildId, 'guild ID');
    final response = await _api.patch(
      '/channels/$normalizedChannelId',
      data: _updatePayload(request),
    );
    return DiscordChannel.fromJson(
      _readMap(response, 'channel update response'),
      fallbackGuildId: normalizedGuildId,
    );
  }

  @override
  Future<void> deleteChannel(String channelId) async {
    final normalizedChannelId = _requiredId(channelId, 'channel ID');
    await _api.delete('/channels/$normalizedChannelId');
  }
}

Map<String, Object?> _createPayload(DiscordCreateChannelRequest request) {
  final name = _channelName(request.name);
  _validateSlowmode(request.slowmodeSeconds);
  final topic = _topic(request.topic, request.type);
  final tags = _tags(request.availableTags, request.type);
  final parentId = _optionalId(request.parentId);
  return {
    'name': name,
    'type': request.type.value,
    ...?_entry('topic', topic),
    ...?_entry('parent_id', parentId),
    if (request.type.supportsTextSettings) ...{
      'rate_limit_per_user': request.slowmodeSeconds,
      'nsfw': request.nsfw,
    },
    if (tags.isNotEmpty) 'available_tags': tags,
  };
}

Map<String, Object?> _updatePayload(DiscordUpdateChannelRequest request) {
  final name = request.name == null ? null : _channelName(request.name!);
  final topic = request.topic == null
      ? null
      : _normalizedTopic(request.topic!, 4096);
  final topicEntry = request.clearTopic
      ? const <String, Object?>{'topic': null}
      : _entry('topic', topic);
  final parentId = _optionalId(request.parentId);
  final slowmode = request.slowmodeSeconds;
  if (slowmode != null) {
    _validateSlowmode(slowmode);
  }
  final payload = <String, Object?>{
    ...?_entry('name', name),
    ...?topicEntry,
    ...?_entry('parent_id', parentId),
    ...?_entry('nsfw', request.nsfw),
    ...?_entry('rate_limit_per_user', slowmode),
  };
  if (payload.isEmpty) {
    throw const InvalidGuildChannelException('수정할 채널 설정이 없습니다.');
  }
  return Map.unmodifiable(payload);
}

List<Map<String, Object?>> _tags(
  List<DiscordForumTagDraft> tags,
  DiscordGuildChannelType type,
) {
  if (tags.isEmpty) {
    return const [];
  }
  if (!type.supportsTags || tags.length > 20) {
    throw const InvalidGuildChannelException('포럼/미디어 태그 설정이 올바르지 않습니다.');
  }
  return List.unmodifiable([for (final tag in tags) _tagPayload(tag)]);
}

Map<String, Object?> _tagPayload(DiscordForumTagDraft tag) {
  final name = tag.name.trim();
  if (name.isEmpty || name.length > 20) {
    throw const InvalidGuildChannelException('태그 이름은 1~20자여야 합니다.');
  }
  final emojiId = _optionalId(tag.emojiId);
  final emojiName = tag.emojiName?.trim();
  if (emojiId != null && emojiName != null && emojiName.isNotEmpty) {
    throw const InvalidGuildChannelException('태그 이모지는 하나만 지정할 수 있습니다.');
  }
  return {
    'name': name,
    'moderated': tag.moderated,
    ...?_entry('emoji_id', emojiId),
    ...?_entry(
      'emoji_name',
      emojiName == null || emojiName.isEmpty ? null : emojiName,
    ),
  };
}

String _channelName(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 100) {
    throw const InvalidGuildChannelException('채널 이름은 1~100자여야 합니다.');
  }
  return normalized;
}

String? _topic(String? value, DiscordGuildChannelType type) {
  if (value == null) {
    return null;
  }
  if (!type.supportsTextSettings) {
    throw const InvalidGuildChannelException('이 채널 유형은 topic을 지원하지 않습니다.');
  }
  return _normalizedTopic(value, type.supportsTags ? 4096 : 1024);
}

String _normalizedTopic(String value, int maxLength) {
  final normalized = value.trim();
  if (normalized.length > maxLength) {
    throw InvalidGuildChannelException('채널 topic은 $maxLength자 이하여야 합니다.');
  }
  return normalized;
}

void _validateSlowmode(int value) {
  if (value < 0 || value > 21600) {
    throw const InvalidGuildChannelException('slowmode는 0~21600초여야 합니다.');
  }
}

String _requiredId(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw InvalidGuildChannelException('$field가 필요합니다.');
  }
  return normalized;
}

String? _optionalId(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

Map<String, Object?>? _entry(String key, Object? value) {
  return value == null ? null : {key: value};
}
