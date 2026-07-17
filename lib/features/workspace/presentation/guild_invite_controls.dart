import 'package:discord_native/features/workspace/data/discord_invite_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef LoadGuildInvitesCallback = Future<List<DiscordGuildInvite>> Function();
typedef CreateGuildInviteCallback =
    Future<DiscordGuildInvite?> Function(
      String channelId,
      DiscordInviteRequest request,
    );
typedef DeleteGuildInviteCallback = Future<void> Function(String code);

class GuildInviteSection extends StatefulWidget {
  const GuildInviteSection({
    required this.channels,
    required this.onLoad,
    required this.onCreate,
    required this.onDelete,
    super.key,
  });

  final List<DiscordChannel> channels;
  final LoadGuildInvitesCallback onLoad;
  final CreateGuildInviteCallback onCreate;
  final DeleteGuildInviteCallback onDelete;

  @override
  State<GuildInviteSection> createState() => _GuildInviteSectionState();
}

class _GuildInviteSectionState extends State<GuildInviteSection> {
  List<DiscordGuildInvite> _invites = const [];
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final invites = await widget.onLoad();
      if (mounted) {
        setState(() {
          _invites = List.unmodifiable(invites);
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = error.toString();
        });
      }
    }
  }

  Future<void> _create() async {
    final draft = await showDialog<_InviteDraft>(
      context: context,
      builder: (context) => _CreateInviteDialog(channels: widget.channels),
    );
    if (draft == null) {
      return;
    }
    try {
      final invite = await widget.onCreate(draft.channelId, draft.request);
      if (mounted && invite != null) {
        setState(() {
          _invites = List.unmodifiable([
            invite,
            ..._invites.where((item) => item.code != invite.code),
          ]);
          _errorMessage = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    }
  }

  Future<void> _delete(DiscordGuildInvite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('초대 삭제'),
        content: Text('${invite.code} 초대를 삭제할까요?'),
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
    if (confirmed != true) {
      return;
    }
    try {
      await widget.onDelete(invite.code);
      if (mounted) {
        setState(() {
          _invites = List.unmodifiable(
            _invites.where((item) => item.code != invite.code),
          );
          _errorMessage = null;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Row(
          children: [
            if (_errorMessage case final message?)
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Color(0xFFF23F42)),
                ),
              )
            else
              const Spacer(),
            IconButton(
              tooltip: '초대 새로고침',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: '초대 만들기',
              onPressed: widget.channels.isEmpty ? null : _create,
              icon: const Icon(Icons.add_link),
            ),
          ],
        ),
        Expanded(
          child: _invites.isEmpty
              ? const Center(child: Text('활성 초대가 없습니다.'))
              : ListView.builder(
                  itemCount: _invites.length,
                  itemBuilder: (context, index) {
                    final invite = _invites[index];
                    return ListTile(
                      title: Text(invite.code),
                      subtitle: Text(_inviteDescription(invite)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '${invite.code} 초대 복사',
                            onPressed: () => Clipboard.setData(
                              ClipboardData(text: invite.url),
                            ),
                            icon: const Icon(Icons.copy),
                          ),
                          IconButton(
                            tooltip: '${invite.code} 초대 삭제',
                            onPressed: () => _delete(invite),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _InviteDraft {
  const _InviteDraft({required this.channelId, required this.request});

  final String channelId;
  final DiscordInviteRequest request;
}

class _CreateInviteDialog extends StatefulWidget {
  const _CreateInviteDialog({required this.channels});

  final List<DiscordChannel> channels;

  @override
  State<_CreateInviteDialog> createState() => _CreateInviteDialogState();
}

class _CreateInviteDialogState extends State<_CreateInviteDialog> {
  final TextEditingController _maxAge = TextEditingController(text: '86400');
  final TextEditingController _maxUses = TextEditingController(text: '0');
  late String _channelId = widget.channels.first.id;
  bool _temporary = false;
  bool _unique = false;

  @override
  void dispose() {
    _maxAge.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  void _submit() {
    final maxAge = int.tryParse(_maxAge.text.trim());
    final maxUses = int.tryParse(_maxUses.text.trim());
    if (maxAge == null ||
        maxAge < 0 ||
        maxAge > 604800 ||
        maxUses == null ||
        maxUses < 0 ||
        maxUses > 100) {
      return;
    }
    Navigator.pop(
      context,
      _InviteDraft(
        channelId: _channelId,
        request: DiscordInviteRequest(
          maxAgeSeconds: maxAge,
          maxUses: maxUses,
          temporary: _temporary,
          unique: _unique,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('초대 만들기'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _channelId,
              decoration: const InputDecoration(labelText: '채널'),
              items: [
                for (final channel in widget.channels)
                  DropdownMenuItem(
                    value: channel.id,
                    child: Text(channel.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _channelId = value);
                }
              },
            ),
            TextField(
              key: const ValueKey('invite-max-age-field'),
              controller: _maxAge,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '만료 초 (0=무제한)'),
            ),
            TextField(
              key: const ValueKey('invite-max-uses-field'),
              controller: _maxUses,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '최대 사용 (0=무제한)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('임시 멤버십'),
              value: _temporary,
              onChanged: (value) => setState(() => _temporary = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('항상 새 코드 생성'),
              value: _unique,
              onChanged: (value) => setState(() => _unique = value),
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

String _inviteDescription(DiscordGuildInvite invite) {
  final uses = invite.maxUses == 0
      ? '${invite.uses}회 사용'
      : '${invite.uses}/${invite.maxUses}회 사용';
  final expiry = invite.expiresAt == null
      ? '만료 없음'
      : '${invite.expiresAt!.toLocal()} 만료';
  return '#${invite.channelName} · $uses · $expiry';
}
