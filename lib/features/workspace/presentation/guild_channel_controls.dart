import 'package:discord_native/features/workspace/data/discord_channel_management_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:flutter/material.dart';

typedef CreateGuildChannelCallback =
    Future<void> Function(DiscordCreateChannelRequest request);
typedef UpdateGuildChannelCallback =
    Future<void> Function(
      String channelId,
      DiscordUpdateChannelRequest request,
    );
typedef DeleteGuildChannelCallback = Future<void> Function(String channelId);

Future<DiscordCreateChannelRequest?> showCreateGuildChannelDialog(
  BuildContext context, {
  required List<DiscordChannel> categories,
}) {
  return showDialog<DiscordCreateChannelRequest>(
    context: context,
    builder: (context) => _CreateGuildChannelDialog(categories: categories),
  );
}

Future<DiscordUpdateChannelRequest?> showUpdateGuildChannelDialog(
  BuildContext context,
  DiscordChannel channel,
) {
  return showDialog<DiscordUpdateChannelRequest>(
    context: context,
    builder: (context) => _UpdateGuildChannelDialog(channel: channel),
  );
}

Future<bool> showDeleteGuildChannelDialog(
  BuildContext context,
  DiscordChannel channel,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${channel.name} 삭제'),
      content: const Text('채널 삭제는 되돌릴 수 없습니다. 계속할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class _CreateGuildChannelDialog extends StatefulWidget {
  const _CreateGuildChannelDialog({required this.categories});

  final List<DiscordChannel> categories;

  @override
  State<_CreateGuildChannelDialog> createState() =>
      _CreateGuildChannelDialogState();
}

class _CreateGuildChannelDialogState extends State<_CreateGuildChannelDialog> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _topic = TextEditingController();
  DiscordGuildChannelType _type = DiscordGuildChannelType.text;
  String? _parentId;
  bool _nsfw = false;

  @override
  void dispose() {
    _name.dispose();
    _topic.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      DiscordCreateChannelRequest(
        name: _name.text,
        type: _type,
        topic: _type.supportsTextSettings ? _topic.text : null,
        parentId: _type == DiscordGuildChannelType.category ? null : _parentId,
        nsfw: _type.supportsTextSettings && _nsfw,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('채널 만들기'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('channel-name-field'),
              controller: _name,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: '채널 이름'),
            ),
            DropdownButtonFormField<DiscordGuildChannelType>(
              key: const ValueKey('channel-type-field'),
              initialValue: _type,
              decoration: const InputDecoration(labelText: '채널 유형'),
              items: _creatableChannelTypes
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(_channelTypeLabel(type)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            if (_type != DiscordGuildChannelType.category &&
                widget.categories.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: _parentId,
                decoration: const InputDecoration(labelText: '카테고리'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('없음')),
                  for (final category in widget.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                ],
                onChanged: (value) => setState(() => _parentId = value),
              ),
            if (_type.supportsTextSettings)
              TextField(
                controller: _topic,
                maxLength: _type.supportsTags ? 4096 : 1024,
                decoration: const InputDecoration(labelText: 'Topic'),
              ),
            if (_type.supportsTextSettings)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('연령 제한 채널'),
                value: _nsfw,
                onChanged: (value) => setState(() => _nsfw = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('만들기')),
      ],
    );
  }
}

class _UpdateGuildChannelDialog extends StatefulWidget {
  const _UpdateGuildChannelDialog({required this.channel});

  final DiscordChannel channel;

  @override
  State<_UpdateGuildChannelDialog> createState() =>
      _UpdateGuildChannelDialogState();
}

class _UpdateGuildChannelDialogState extends State<_UpdateGuildChannelDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.channel.name,
  );
  late final TextEditingController _topic = TextEditingController(
    text: widget.channel.topic,
  );
  late bool _nsfw = widget.channel.nsfw;

  @override
  void dispose() {
    _name.dispose();
    _topic.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      return;
    }
    Navigator.pop(
      context,
      DiscordUpdateChannelRequest(
        name: _name.text,
        topic: widget.channel.isCategory ? null : _topic.text,
        nsfw: widget.channel.isCategory ? null : _nsfw,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('채널 편집'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('channel-name-field'),
              controller: _name,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: '채널 이름'),
            ),
            if (!widget.channel.isCategory)
              TextField(
                controller: _topic,
                maxLength: widget.channel.isForum || widget.channel.isMedia
                    ? 4096
                    : 1024,
                decoration: const InputDecoration(labelText: 'Topic'),
              ),
            if (!widget.channel.isCategory)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('연령 제한 채널'),
                value: _nsfw,
                onChanged: (value) => setState(() => _nsfw = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('저장')),
      ],
    );
  }
}

const List<DiscordGuildChannelType> _creatableChannelTypes = [
  DiscordGuildChannelType.text,
  DiscordGuildChannelType.category,
  DiscordGuildChannelType.announcement,
  DiscordGuildChannelType.forum,
];

String _channelTypeLabel(DiscordGuildChannelType type) {
  return switch (type) {
    DiscordGuildChannelType.text => '텍스트',
    DiscordGuildChannelType.category => '카테고리',
    DiscordGuildChannelType.announcement => '공지',
    DiscordGuildChannelType.forum => '포럼',
    DiscordGuildChannelType.voice => '음성',
    DiscordGuildChannelType.media => '미디어',
  };
}
