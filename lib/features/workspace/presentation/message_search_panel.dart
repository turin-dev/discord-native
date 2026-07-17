import 'package:discord_native/features/messages/domain/discord_message_search_state.dart';
import 'package:discord_native/features/messages/domain/discord_message_state.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:flutter/material.dart';

typedef SearchMessagesCallback =
    Future<void> Function(String query, bool currentChannelOnly);
typedef SelectSearchResultCallback =
    Future<void> Function(DiscordMessage message);

class MessageSearchPanel extends StatefulWidget {
  const MessageSearchPanel({
    required this.state,
    required this.channels,
    required this.onSearch,
    required this.onSelectResult,
    required this.onClear,
    super.key,
  });

  final DiscordMessageSearchState state;
  final List<DiscordChannel> channels;
  final SearchMessagesCallback? onSearch;
  final SelectSearchResultCallback? onSelectResult;
  final VoidCallback? onClear;

  @override
  State<MessageSearchPanel> createState() => _MessageSearchPanelState();
}

class _MessageSearchPanelState extends State<MessageSearchPanel> {
  late final TextEditingController _query;
  late bool _currentChannelOnly;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.state.query);
    _currentChannelOnly = widget.state.currentChannelOnly;
  }

  @override
  void didUpdateWidget(MessageSearchPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.query != widget.state.query) {
      _query.text = widget.state.query;
    }
    if (oldWidget.state.currentChannelOnly != widget.state.currentChannelOnly) {
      _currentChannelOnly = widget.state.currentChannelOnly;
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final callback = widget.onSearch;
    final query = _query.text.trim();
    if (callback != null && query.isNotEmpty) {
      await callback(query, _currentChannelOnly);
    }
  }

  void _clear() {
    _query.clear();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF2B2D31),
      child: SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchHeader(onClear: widget.onClear == null ? null : _clear),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                key: const ValueKey('message-search-field'),
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: '메시지 내용 검색',
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: '메시지 검색 실행',
                    onPressed: widget.onSearch == null ? null : _submit,
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),
            CheckboxListTile(
              key: const ValueKey('current-channel-only'),
              dense: true,
              value: _currentChannelOnly,
              onChanged: widget.onSearch == null
                  ? null
                  : (value) {
                      setState(() => _currentChannelOnly = value == true);
                    },
              title: const Text('현재 채널만', style: TextStyle(fontSize: 12)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (widget.state.isLoading) const LinearProgressIndicator(),
            if (widget.state.errorMessage case final message?)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  message,
                  style: const TextStyle(color: Color(0xFFF23F42)),
                ),
              ),
            if (widget.state.query.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Text(
                  '결과 ${widget.state.totalResults}개',
                  style: const TextStyle(
                    color: Color(0xFF949BA4),
                    fontSize: 12,
                  ),
                ),
              ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (widget.state.query.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          '서버의 메시지 내용을 검색할 수 있습니다.',
          style: TextStyle(color: Color(0xFF949BA4)),
        ),
      );
    }
    if (widget.state.messages.isEmpty && !widget.state.isLoading) {
      return const Center(
        child: Text('검색 결과가 없습니다.', style: TextStyle(color: Color(0xFF949BA4))),
      );
    }
    return ListView.builder(
      itemCount: widget.state.messages.length,
      itemBuilder: (context, index) {
        final message = widget.state.messages[index];
        return ListTile(
          dense: true,
          title: Text(
            message.content.isEmpty ? '(내용 없음)' : message.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${message.authorName} · #${_channelName(message.channelId)}',
          ),
          onTap: widget.onSelectResult == null
              ? null
              : () => widget.onSelectResult!(message),
        );
      },
    );
  }

  String _channelName(String channelId) {
    for (final channel in widget.channels) {
      if (channel.id == channelId) {
        return channel.name;
      }
    }
    return channelId;
  }
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.onClear});

  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              '메시지 검색',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: '검색 지우기',
            onPressed: onClear,
            icon: const Icon(Icons.clear),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
