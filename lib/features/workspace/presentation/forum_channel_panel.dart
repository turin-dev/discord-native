import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:flutter/material.dart';

typedef CreateForumPostCallback =
    Future<void> Function(
      String forumChannelId, {
      required String title,
      required String content,
      List<String> appliedTagIds,
    });

class ForumChannelPanel extends StatelessWidget {
  const ForumChannelPanel({
    required this.channel,
    required this.posts,
    required this.onSelectPost,
    this.onRefresh,
    this.onCreatePost,
    super.key,
  });

  final DiscordChannel channel;
  final List<DiscordChannel> posts;
  final ValueChanged<String> onSelectPost;
  final Future<void> Function()? onRefresh;
  final CreateForumPostCallback? onCreatePost;

  Future<void> _create(BuildContext context) async {
    final callback = onCreatePost;
    if (callback == null) {
      return;
    }
    final draft = await showDialog<_ForumPostDraft>(
      context: context,
      builder: (context) =>
          _CreateForumPostDialog(availableTags: channel.availableTags),
    );
    if (draft != null) {
      await callback(
        channel.id,
        title: draft.title,
        content: draft.content,
        appliedTagIds: draft.tagIds,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1F2023))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (channel.topic case final topic?)
                      Text(
                        topic,
                        style: const TextStyle(color: Color(0xFFB5BAC1)),
                      ),
                  ],
                ),
              ),
              if (onRefresh != null)
                IconButton(
                  tooltip: '포럼 새로고침',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              if (onCreatePost != null)
                Tooltip(
                  message: '포럼 글 작성',
                  child: FilledButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add),
                    label: const Text('새 글'),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: posts.isEmpty
              ? const Center(
                  child: Text(
                    '아직 포럼 글이 없습니다.',
                    style: TextStyle(color: Color(0xFFB5BAC1)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return Card(
                      child: ListTile(
                        title: Text(post.name),
                        subtitle: _PostTags(
                          tagIds: post.appliedTagIds,
                          availableTags: channel.availableTags,
                        ),
                        trailing: post.isArchived
                            ? const Text('보관됨')
                            : const Icon(Icons.chevron_right),
                        onTap: () => onSelectPost(post.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PostTags extends StatelessWidget {
  const _PostTags({required this.tagIds, required this.availableTags});

  final List<String> tagIds;
  final List<DiscordForumTag> availableTags;

  @override
  Widget build(BuildContext context) {
    final tags = availableTags.where((tag) => tagIds.contains(tag.id)).toList();
    if (tags.isEmpty) {
      return const Text('태그 없음');
    }
    return Wrap(
      spacing: 6,
      children: [
        for (final tag in tags)
          Chip(label: Text(tag.name), visualDensity: VisualDensity.compact),
      ],
    );
  }
}

class _ForumPostDraft {
  const _ForumPostDraft({
    required this.title,
    required this.content,
    required this.tagIds,
  });

  final String title;
  final String content;
  final List<String> tagIds;
}

class _CreateForumPostDialog extends StatefulWidget {
  const _CreateForumPostDialog({required this.availableTags});

  final List<DiscordForumTag> availableTags;

  @override
  State<_CreateForumPostDialog> createState() => _CreateForumPostDialogState();
}

class _CreateForumPostDialogState extends State<_CreateForumPostDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();
  Set<String> _selectedTagIds = const {};

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _toggleTag(String tagId, bool selected) {
    setState(() {
      _selectedTagIds = selected
          ? {..._selectedTagIds, tagId}
          : _selectedTagIds.where((id) => id != tagId).toSet();
    });
  }

  void _submit() {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty || _selectedTagIds.length > 5) {
      return;
    }
    Navigator.pop(
      context,
      _ForumPostDraft(
        title: title,
        content: content,
        tagIds: List.unmodifiable(_selectedTagIds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('포럼 글 작성'),
      content: SizedBox(
        width: 520,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              key: const ValueKey('forum-title-field'),
              controller: _title,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            TextField(
              key: const ValueKey('forum-content-field'),
              controller: _content,
              minLines: 4,
              maxLines: 10,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: '본문'),
            ),
            for (final tag in widget.availableTags)
              CheckboxListTile(
                key: ValueKey('forum-tag-${tag.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(tag.name),
                subtitle: tag.moderated ? const Text('관리자 전용 태그') : null,
                value: _selectedTagIds.contains(tag.id),
                onChanged: tag.moderated
                    ? null
                    : (value) => _toggleTag(tag.id, value == true),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('게시')),
      ],
    );
  }
}
