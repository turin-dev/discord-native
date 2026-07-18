part 'discord_poll.dart';

final class DiscordAttachment {
  const DiscordAttachment({
    required this.id,
    required this.filename,
    required this.url,
    required this.proxyUrl,
    required this.size,
    this.contentType,
    this.width,
    this.height,
  });

  factory DiscordAttachment.fromJson(Map<String, Object?> json) {
    return DiscordAttachment(
      id: _requiredString(json['id'], 'attachment.id'),
      filename: _requiredString(json['filename'], 'attachment.filename'),
      url: _requiredString(json['url'], 'attachment.url'),
      proxyUrl: _requiredString(json['proxy_url'], 'attachment.proxy_url'),
      size: _requiredInt(json['size'], 'attachment.size'),
      contentType: _optionalString(json['content_type']),
      width: _optionalInt(json['width']),
      height: _optionalInt(json['height']),
    );
  }

  final String id;
  final String filename;
  final String url;
  final String proxyUrl;
  final int size;
  final String? contentType;
  final int? width;
  final int? height;

  bool get isImage => contentType?.startsWith('image/') == true;

  bool get isVideo => contentType?.startsWith('video/') == true;
}

final class DiscordReaction {
  const DiscordReaction({
    required this.emojiName,
    required this.count,
    required this.me,
    this.emojiId,
  });

  factory DiscordReaction.fromJson(Map<String, Object?> json) {
    final emoji = _readMap(json['emoji'], 'reaction.emoji');
    return DiscordReaction(
      emojiName: _requiredString(emoji['name'], 'reaction.emoji.name'),
      emojiId: _optionalString(emoji['id']),
      count: _requiredInt(json['count'], 'reaction.count'),
      me: json['me'] == true,
    );
  }

  final String emojiName;
  final String? emojiId;
  final int count;
  final bool me;

  String get key => emojiId == null ? emojiName : '$emojiName:$emojiId';
}

final class DiscordMention {
  const DiscordMention({
    required this.id,
    required this.username,
    required this.displayName,
  });

  factory DiscordMention.fromJson(Map<String, Object?> json) {
    final username = _requiredString(json['username'], 'mention.username');
    return DiscordMention(
      id: _requiredString(json['id'], 'mention.id'),
      username: username,
      displayName: _optionalString(json['global_name']) ?? username,
    );
  }

  final String id;
  final String username;
  final String displayName;
}

final class DiscordEmbedMedia {
  const DiscordEmbedMedia({
    required this.url,
    this.proxyUrl,
    this.width,
    this.height,
  });

  factory DiscordEmbedMedia.fromJson(Map<String, Object?> json) {
    return DiscordEmbedMedia(
      url: _requiredString(json['url'], 'embed.media.url'),
      proxyUrl: _optionalString(json['proxy_url']),
      width: _optionalInt(json['width']),
      height: _optionalInt(json['height']),
    );
  }

  final String url;
  final String? proxyUrl;
  final int? width;
  final int? height;
}

final class DiscordEmbedField {
  const DiscordEmbedField({
    required this.name,
    required this.value,
    required this.inline,
  });

  factory DiscordEmbedField.fromJson(Map<String, Object?> json) {
    return DiscordEmbedField(
      name: _requiredString(json['name'], 'embed.field.name'),
      value: _requiredString(json['value'], 'embed.field.value'),
      inline: json['inline'] == true,
    );
  }

  final String name;
  final String value;
  final bool inline;
}

final class DiscordEmbed {
  const DiscordEmbed({
    this.title,
    this.description,
    this.url,
    this.color,
    this.authorName,
    this.footerText,
    this.fields = const [],
    this.image,
    this.thumbnail,
  });

  factory DiscordEmbed.fromJson(Map<String, Object?> json) {
    final author = _optionalMap(json['author']);
    final footer = _optionalMap(json['footer']);
    final image = _optionalMap(json['image']);
    final thumbnail = _optionalMap(json['thumbnail']);
    return DiscordEmbed(
      title: _optionalString(json['title']),
      description: _optionalString(json['description']),
      url: _optionalString(json['url']),
      color: _optionalInt(json['color']),
      authorName: author == null ? null : _optionalString(author['name']),
      footerText: footer == null ? null : _optionalString(footer['text']),
      fields: List.unmodifiable([
        for (final item in _readList(json['fields']))
          DiscordEmbedField.fromJson(_readMap(item, 'embed.field')),
      ]),
      image: image == null ? null : DiscordEmbedMedia.fromJson(image),
      thumbnail: thumbnail == null
          ? null
          : DiscordEmbedMedia.fromJson(thumbnail),
    );
  }

  final String? title;
  final String? description;
  final String? url;
  final int? color;
  final String? authorName;
  final String? footerText;
  final List<DiscordEmbedField> fields;
  final DiscordEmbedMedia? image;
  final DiscordEmbedMedia? thumbnail;
}

final class DiscordSticker {
  const DiscordSticker({
    required this.id,
    required this.name,
    required this.formatType,
  });

  factory DiscordSticker.fromJson(Map<String, Object?> json) {
    return DiscordSticker(
      id: _requiredString(json['id'], 'sticker.id'),
      name: _requiredString(json['name'], 'sticker.name'),
      formatType: _requiredInt(json['format_type'], 'sticker.format_type'),
    );
  }

  final String id;
  final String name;
  final int formatType;
}

final class DiscordMessageReference {
  const DiscordMessageReference({
    required this.messageId,
    required this.channelId,
    this.guildId,
  });

  factory DiscordMessageReference.fromJson(Map<String, Object?> json) {
    return DiscordMessageReference(
      messageId: _requiredString(json['message_id'], 'reference.message_id'),
      channelId: _requiredString(json['channel_id'], 'reference.channel_id'),
      guildId: _optionalString(json['guild_id']),
    );
  }

  final String messageId;
  final String channelId;
  final String? guildId;
}

final class DiscordMessage {
  const DiscordMessage({
    required this.id,
    required this.channelId,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.timestamp,
    this.authorAvatarHash,
    this.editedTimestamp,
    this.reference,
    this.referencedMessage,
    this.attachments = const [],
    this.reactions = const [],
    this.mentions = const [],
    this.mentionRoleIds = const [],
    this.embeds = const [],
    this.stickers = const [],
    this.poll,
    this.pinned = false,
  });

  factory DiscordMessage.fromJson(
    Map<String, Object?> json, {
    bool includeReferencedMessage = true,
  }) {
    final author = _readMap(json['author'], 'message.author');
    final reference = _optionalMap(json['message_reference']);
    final referencedMessage = includeReferencedMessage
        ? _optionalMap(json['referenced_message'])
        : null;
    return DiscordMessage(
      id: _requiredString(json['id'], 'message.id'),
      channelId: _requiredString(json['channel_id'], 'message.channel_id'),
      content: _optionalString(json['content']) ?? '',
      authorId: _requiredString(author['id'], 'message.author.id'),
      authorName: _requiredString(
        author['global_name'] ?? author['username'],
        'message.author.username',
      ),
      authorAvatarHash: _optionalString(author['avatar']),
      timestamp: _requiredDate(json['timestamp'], 'message.timestamp'),
      editedTimestamp: _optionalDate(json['edited_timestamp']),
      reference: reference == null
          ? null
          : DiscordMessageReference.fromJson(reference),
      referencedMessage: referencedMessage == null
          ? null
          : DiscordMessage.fromJson(
              referencedMessage,
              includeReferencedMessage: false,
            ),
      attachments: List.unmodifiable([
        for (final item in _readList(json['attachments']))
          DiscordAttachment.fromJson(_readMap(item, 'attachment')),
      ]),
      reactions: List.unmodifiable([
        for (final item in _readList(json['reactions']))
          DiscordReaction.fromJson(_readMap(item, 'reaction')),
      ]),
      mentions: List.unmodifiable([
        for (final item in _readList(json['mentions']))
          DiscordMention.fromJson(_readMap(item, 'mention')),
      ]),
      mentionRoleIds: List.unmodifiable(
        _readList(json['mention_roles']).whereType<String>(),
      ),
      embeds: List.unmodifiable([
        for (final item in _readList(json['embeds']))
          DiscordEmbed.fromJson(_readMap(item, 'embed')),
      ]),
      stickers: List.unmodifiable([
        for (final item in _readList(json['sticker_items']))
          DiscordSticker.fromJson(_readMap(item, 'sticker')),
      ]),
      poll: _optionalPoll(json['poll']),
      pinned: json['pinned'] == true,
    );
  }

  final String id;
  final String channelId;
  final String content;
  final String authorId;
  final String authorName;
  final String? authorAvatarHash;
  final DateTime timestamp;
  final DateTime? editedTimestamp;
  final DiscordMessageReference? reference;
  final DiscordMessage? referencedMessage;
  final List<DiscordAttachment> attachments;
  final List<DiscordReaction> reactions;
  final List<DiscordMention> mentions;
  final List<String> mentionRoleIds;
  final List<DiscordEmbed> embeds;
  final List<DiscordSticker> stickers;
  final DiscordPoll? poll;
  final bool pinned;

  String get displayContent {
    return _replaceMentions(content).replaceAllMapped(
      RegExp(r'<a?:([A-Za-z0-9_]+):[A-Za-z0-9_-]+>'),
      (match) => ':${match.group(1)}:',
    );
  }

  String get markdownContent {
    return _replaceMentions(
      content,
    ).replaceAllMapped(RegExp(r'<a?:([A-Za-z0-9_]+):([A-Za-z0-9_-]+)>'), (
      match,
    ) {
      final name = match.group(1);
      final id = match.group(2);
      return '![:$name:](https://cdn.discordapp.com/emojis/$id.png?size=48&quality=lossless)';
    });
  }

  String _replaceMentions(String value) {
    final mentionsById = {
      for (final mention in mentions) mention.id: mention.displayName,
    };
    return value
        .replaceAllMapped(
          RegExp(r'<@!?([A-Za-z0-9_-]+)>'),
          (match) => '@${mentionsById[match.group(1)] ?? match.group(1)}',
        )
        .replaceAllMapped(
          RegExp(r'<#([A-Za-z0-9_-]+)>'),
          (match) => '#${match.group(1)}',
        )
        .replaceAllMapped(
          RegExp(r'<@&([A-Za-z0-9_-]+)>'),
          (match) => '@${match.group(1)}',
        );
  }

  DiscordMessage mergeJson(Map<String, Object?> json) {
    final author = _optionalMap(json['author']);
    final reference = json.containsKey('message_reference')
        ? _optionalMap(json['message_reference'])
        : null;
    final referenced = json.containsKey('referenced_message')
        ? _optionalMap(json['referenced_message'])
        : null;
    return DiscordMessage(
      id: id,
      channelId: channelId,
      content: json.containsKey('content')
          ? _optionalString(json['content']) ?? ''
          : content,
      authorId: author == null
          ? authorId
          : _requiredString(author['id'], 'message.author.id'),
      authorName: author == null
          ? authorName
          : _requiredString(
              author['global_name'] ?? author['username'],
              'message.author.username',
            ),
      authorAvatarHash: author == null || !author.containsKey('avatar')
          ? authorAvatarHash
          : _optionalString(author['avatar']),
      timestamp: _optionalDate(json['timestamp']) ?? timestamp,
      editedTimestamp: json.containsKey('edited_timestamp')
          ? _optionalDate(json['edited_timestamp'])
          : editedTimestamp,
      reference: json.containsKey('message_reference')
          ? reference == null
                ? null
                : DiscordMessageReference.fromJson(reference)
          : this.reference,
      referencedMessage: json.containsKey('referenced_message')
          ? referenced == null
                ? null
                : DiscordMessage.fromJson(
                    referenced,
                    includeReferencedMessage: false,
                  )
          : referencedMessage,
      attachments: json.containsKey('attachments')
          ? List.unmodifiable([
              for (final item in _readList(json['attachments']))
                DiscordAttachment.fromJson(_readMap(item, 'attachment')),
            ])
          : attachments,
      reactions: json.containsKey('reactions')
          ? List.unmodifiable([
              for (final item in _readList(json['reactions']))
                DiscordReaction.fromJson(_readMap(item, 'reaction')),
            ])
          : reactions,
      mentions: json.containsKey('mentions')
          ? List.unmodifiable([
              for (final item in _readList(json['mentions']))
                DiscordMention.fromJson(_readMap(item, 'mention')),
            ])
          : mentions,
      mentionRoleIds: json.containsKey('mention_roles')
          ? List.unmodifiable(
              _readList(json['mention_roles']).whereType<String>(),
            )
          : mentionRoleIds,
      embeds: json.containsKey('embeds')
          ? List.unmodifiable([
              for (final item in _readList(json['embeds']))
                DiscordEmbed.fromJson(_readMap(item, 'embed')),
            ])
          : embeds,
      stickers: json.containsKey('sticker_items')
          ? List.unmodifiable([
              for (final item in _readList(json['sticker_items']))
                DiscordSticker.fromJson(_readMap(item, 'sticker')),
            ])
          : stickers,
      poll: json.containsKey('poll') ? _optionalPoll(json['poll']) : poll,
      pinned: json['pinned'] is bool ? json['pinned'] as bool : pinned,
    );
  }

  DiscordMessage copyWith({String? content, DiscordPoll? poll, bool? pinned}) {
    return DiscordMessage(
      id: id,
      channelId: channelId,
      content: content ?? this.content,
      authorId: authorId,
      authorName: authorName,
      authorAvatarHash: authorAvatarHash,
      timestamp: timestamp,
      editedTimestamp: editedTimestamp,
      reference: reference,
      referencedMessage: referencedMessage,
      attachments: attachments,
      reactions: reactions,
      mentions: mentions,
      mentionRoleIds: mentionRoleIds,
      embeds: embeds,
      stickers: stickers,
      poll: poll ?? this.poll,
      pinned: pinned ?? this.pinned,
    );
  }
}

final class DiscordMessageState {
  const DiscordMessageState({
    this.channelId,
    this.messages = const [],
    this.mediaProxyUrls = const {},
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.hasMore = false,
    this.errorMessage,
    this.olderErrorMessage,
  });

  factory DiscordMessageState.loaded(
    String channelId,
    List<DiscordMessage> messages, {
    bool hasMore = false,
    Map<String, String> mediaProxyUrls = const {},
  }) {
    return DiscordMessageState(
      channelId: channelId,
      messages: List.unmodifiable(_sortMessages(messages)),
      mediaProxyUrls: Map.unmodifiable(mediaProxyUrls),
      hasMore: hasMore,
    );
  }

  final String? channelId;
  final List<DiscordMessage> messages;
  final Map<String, String> mediaProxyUrls;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool hasMore;
  final String? errorMessage;
  final String? olderErrorMessage;

  DiscordMessageState payloadReceived(
    Map<String, Object?> payload, {
    String? currentUserId,
  }) {
    if (payload['op'] != 0) {
      return this;
    }
    final data = _readMap(payload['d'], 'message dispatch data');
    final eventChannelId = _optionalString(data['channel_id']);
    if (eventChannelId != channelId) {
      return this;
    }
    return switch (payload['t']) {
      'MESSAGE_CREATE' => add(DiscordMessage.fromJson(data)),
      'MESSAGE_UPDATE' => update(data),
      'MESSAGE_DELETE' => remove(_requiredString(data['id'], 'message.id')),
      'MESSAGE_POLL_VOTE_ADD' => updatePollVote(
        _requiredString(data['message_id'], 'poll vote.message_id'),
        _requiredInt(data['answer_id'], 'poll vote.answer_id'),
        voted: true,
        isCurrentUser:
            currentUserId != null && data['user_id'] == currentUserId,
      ),
      'MESSAGE_POLL_VOTE_REMOVE' => updatePollVote(
        _requiredString(data['message_id'], 'poll vote.message_id'),
        _requiredInt(data['answer_id'], 'poll vote.answer_id'),
        voted: false,
        isCurrentUser:
            currentUserId != null && data['user_id'] == currentUserId,
      ),
      _ => this,
    };
  }

  DiscordMessageState setPollSelection(String messageId, Set<int> answerIds) {
    for (final message in messages) {
      if (message.id == messageId && message.poll != null) {
        return add(
          message.copyWith(poll: message.poll!.applySelection(answerIds)),
        );
      }
    }
    return this;
  }

  DiscordMessageState updatePollVote(
    String messageId,
    int answerId, {
    required bool voted,
    required bool isCurrentUser,
  }) {
    for (final message in messages) {
      if (message.id == messageId && message.poll != null) {
        return add(
          message.copyWith(
            poll: message.poll!.applyVoteEvent(
              answerId,
              voted: voted,
              isCurrentUser: isCurrentUser,
            ),
          ),
        );
      }
    }
    return this;
  }

  DiscordMessageState add(DiscordMessage message) {
    final nextMessages = [
      for (final item in messages)
        if (item.id != message.id) item,
      message,
    ];
    return copyWith(
      channelId: channelId ?? message.channelId,
      messages: _sortMessages(nextMessages),
      isLoading: false,
      errorMessage: null,
    );
  }

  DiscordMessageState remove(String messageId) {
    return copyWith(
      channelId: channelId ?? '',
      messages: messages.where((message) => message.id != messageId).toList(),
    );
  }

  DiscordMessageState update(Map<String, Object?> data) {
    final messageId = _requiredString(data['id'], 'message.id');
    for (final message in messages) {
      if (message.id == messageId) {
        return add(message.mergeJson(data));
      }
    }
    return this;
  }

  DiscordMessageState loadingOlder() {
    return copyWith(isLoadingOlder: true, olderErrorMessage: null);
  }

  DiscordMessageState prependOlder(
    List<DiscordMessage> olderMessages, {
    required bool hasMore,
  }) {
    final byId = {
      for (final message in messages) message.id: message,
      for (final message in olderMessages) message.id: message,
    };
    return copyWith(
      messages: _sortMessages(byId.values.toList()),
      isLoadingOlder: false,
      hasMore: hasMore,
      olderErrorMessage: null,
    );
  }

  DiscordMessageState copyWith({
    String? channelId,
    List<DiscordMessage>? messages,
    Map<String, String>? mediaProxyUrls,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? hasMore,
    Object? errorMessage = _unset,
    Object? olderErrorMessage = _unset,
  }) {
    return DiscordMessageState(
      channelId: channelId ?? this.channelId,
      messages: List.unmodifiable(messages ?? this.messages),
      mediaProxyUrls: Map.unmodifiable(mediaProxyUrls ?? this.mediaProxyUrls),
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      olderErrorMessage: identical(olderErrorMessage, _unset)
          ? this.olderErrorMessage
          : olderErrorMessage as String?,
    );
  }
}

const Object _unset = Object();

List<DiscordMessage> _sortMessages(List<DiscordMessage> messages) {
  final sorted = [...messages];
  sorted.sort((left, right) => left.timestamp.compareTo(right.timestamp));
  return sorted;
}

Map<String, Object?> _readMap(Object? value, String field) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field 형식이 올바르지 않습니다.');
}

Map<String, Object?>? _optionalMap(Object? value) {
  if (value == null) {
    return null;
  }
  return _readMap(value, 'optional object');
}

List<Object?> _readList(Object? value) {
  return value is List ? List.unmodifiable(value) : const [];
}

String _requiredString(Object? value, String field) {
  final string = _optionalString(value);
  if (string == null) {
    throw FormatException('$field 형식이 올바르지 않습니다.');
  }
  return string;
}

String? _optionalString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

DateTime _requiredDate(Object? value, String field) {
  final date = _optionalDate(value);
  if (date == null) {
    throw FormatException('$field 형식이 올바르지 않습니다.');
  }
  return date;
}

DateTime? _optionalDate(Object? value) {
  return value is String ? DateTime.tryParse(value) : null;
}

int _requiredInt(Object? value, String field) {
  final integer = _optionalInt(value);
  if (integer == null) {
    throw FormatException('$field 형식이 올바르지 않습니다.');
  }
  return integer;
}

int? _optionalInt(Object? value) {
  return value is num ? value.toInt() : null;
}
