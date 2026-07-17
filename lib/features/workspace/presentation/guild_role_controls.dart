import 'package:discord_native/features/workspace/data/discord_role_repository.dart';
import 'package:discord_native/features/workspace/domain/discord_permissions.dart';
import 'package:discord_native/features/workspace/domain/discord_workspace_state.dart';
import 'package:discord_native/features/workspace/presentation/guild_event_controls.dart';
import 'package:discord_native/features/workspace/presentation/guild_invite_controls.dart';
import 'package:flutter/material.dart';

typedef CreateGuildRoleCallback =
    Future<void> Function(DiscordRoleRequest request);
typedef UpdateGuildRoleCallback =
    Future<void> Function(String roleId, DiscordRoleRequest request);
typedef UpdateGuildRolePositionsCallback =
    Future<void> Function(Map<String, int> positions);
typedef DeleteGuildRoleCallback = Future<void> Function(String roleId);

Future<void> showGuildRoleManagementDialog(
  BuildContext context, {
  required DiscordGuild guild,
  required List<DiscordChannel> channels,
  CreateGuildRoleCallback? onCreate,
  UpdateGuildRoleCallback? onUpdate,
  UpdateGuildRolePositionsCallback? onUpdatePositions,
  DeleteGuildRoleCallback? onDelete,
  LoadGuildInvitesCallback? onLoadInvites,
  CreateGuildInviteCallback? onCreateInvite,
  DeleteGuildInviteCallback? onDeleteInvite,
  LoadScheduledEventsCallback? onLoadEvents,
  CreateScheduledEventCallback? onCreateEvent,
  UpdateScheduledEventCallback? onUpdateEvent,
  DeleteScheduledEventCallback? onDeleteEvent,
}) {
  final canManageRoles =
      onCreate != null &&
      onUpdate != null &&
      onUpdatePositions != null &&
      onDelete != null;
  final canManageInvites =
      onLoadInvites != null && onCreateInvite != null && onDeleteInvite != null;
  final canManageEvents =
      onLoadEvents != null &&
      onCreateEvent != null &&
      onUpdateEvent != null &&
      onDeleteEvent != null;
  if (!canManageRoles && !canManageInvites && !canManageEvents) {
    return Future.value();
  }
  return showDialog<void>(
    context: context,
    builder: (context) => DefaultTabController(
      length:
          (canManageRoles ? 1 : 0) +
          (canManageInvites ? 1 : 0) +
          (canManageEvents ? 1 : 0),
      child: _GuildManagementDialog(
        guild: guild,
        channels: channels,
        onCreateRole: onCreate,
        onUpdateRole: onUpdate,
        onUpdateRolePositions: onUpdatePositions,
        onDeleteRole: onDelete,
        onLoadInvites: onLoadInvites,
        onCreateInvite: onCreateInvite,
        onDeleteInvite: onDeleteInvite,
        onLoadEvents: onLoadEvents,
        onCreateEvent: onCreateEvent,
        onUpdateEvent: onUpdateEvent,
        onDeleteEvent: onDeleteEvent,
      ),
    ),
  );
}

class _GuildManagementDialog extends StatelessWidget {
  const _GuildManagementDialog({
    required this.guild,
    required this.channels,
    this.onCreateRole,
    this.onUpdateRole,
    this.onUpdateRolePositions,
    this.onDeleteRole,
    this.onLoadInvites,
    this.onCreateInvite,
    this.onDeleteInvite,
    this.onLoadEvents,
    this.onCreateEvent,
    this.onUpdateEvent,
    this.onDeleteEvent,
  });

  final DiscordGuild guild;
  final List<DiscordChannel> channels;
  final CreateGuildRoleCallback? onCreateRole;
  final UpdateGuildRoleCallback? onUpdateRole;
  final UpdateGuildRolePositionsCallback? onUpdateRolePositions;
  final DeleteGuildRoleCallback? onDeleteRole;
  final LoadGuildInvitesCallback? onLoadInvites;
  final CreateGuildInviteCallback? onCreateInvite;
  final DeleteGuildInviteCallback? onDeleteInvite;
  final LoadScheduledEventsCallback? onLoadEvents;
  final CreateScheduledEventCallback? onCreateEvent;
  final UpdateScheduledEventCallback? onUpdateEvent;
  final DeleteScheduledEventCallback? onDeleteEvent;

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[];
    final views = <Widget>[];
    if (onCreateRole != null &&
        onUpdateRole != null &&
        onUpdateRolePositions != null &&
        onDeleteRole != null) {
      tabs.add(const Tab(text: '역할'));
      views.add(
        _GuildRoleSection(
          guild: guild,
          onCreate: onCreateRole!,
          onUpdate: onUpdateRole!,
          onUpdatePositions: onUpdateRolePositions!,
          onDelete: onDeleteRole!,
        ),
      );
    }
    if (onLoadInvites != null &&
        onCreateInvite != null &&
        onDeleteInvite != null) {
      tabs.add(const Tab(text: '초대'));
      views.add(
        GuildInviteSection(
          channels: channels,
          onLoad: onLoadInvites!,
          onCreate: onCreateInvite!,
          onDelete: onDeleteInvite!,
        ),
      );
    }
    if (onLoadEvents != null &&
        onCreateEvent != null &&
        onUpdateEvent != null &&
        onDeleteEvent != null) {
      tabs.add(const Tab(text: '이벤트'));
      views.add(
        GuildEventSection(
          onLoad: onLoadEvents!,
          onCreate: onCreateEvent!,
          onUpdate: onUpdateEvent!,
          onDelete: onDeleteEvent!,
        ),
      );
    }
    return AlertDialog(
      title: const Text('서버 설정'),
      content: SizedBox(
        width: 620,
        height: 480,
        child: Column(
          children: [
            TabBar(tabs: tabs),
            Expanded(child: TabBarView(children: views)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _GuildRoleSection extends StatelessWidget {
  const _GuildRoleSection({
    required this.guild,
    required this.onCreate,
    required this.onUpdate,
    required this.onUpdatePositions,
    required this.onDelete,
  });

  final DiscordGuild guild;
  final CreateGuildRoleCallback onCreate;
  final UpdateGuildRoleCallback onUpdate;
  final UpdateGuildRolePositionsCallback onUpdatePositions;
  final DeleteGuildRoleCallback onDelete;

  Future<void> _create(BuildContext context) async {
    final request = await _showRoleEditor(context);
    if (request != null) {
      await onCreate(request);
    }
  }

  Future<void> _update(BuildContext context, DiscordRole role) async {
    final request = await _showRoleEditor(context, role: role);
    if (request != null) {
      await onUpdate(role.id, request);
    }
  }

  Future<void> _delete(BuildContext context, DiscordRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${role.name} 역할 삭제'),
        content: const Text('이 역할을 삭제할까요?'),
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
    if (confirmed == true) {
      await onDelete(role.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles =
        guild.roles
            .where((role) => role.id != guild.id && !role.managed)
            .toList()
          ..sort((left, right) => right.position.compareTo(left.position));
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: '역할 만들기',
            onPressed: () => _create(context),
            icon: const Icon(Icons.add),
          ),
        ),
        Expanded(
          child: roles.isEmpty
              ? const Center(child: Text('관리할 역할이 없습니다.'))
              : ListView.builder(
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 8,
                        backgroundColor: Color(0xFF000000 | role.color),
                      ),
                      title: Text(role.name),
                      subtitle: Text('position ${role.position}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '${role.name} 역할 위로',
                            onPressed: () =>
                                onUpdatePositions({role.id: role.position + 1}),
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            tooltip: '${role.name} 역할 아래로',
                            onPressed: role.position <= 1
                                ? null
                                : () => onUpdatePositions({
                                    role.id: role.position - 1,
                                  }),
                            icon: const Icon(Icons.arrow_downward),
                          ),
                          IconButton(
                            tooltip: '${role.name} 역할 설정',
                            onPressed: () => _update(context, role),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            tooltip: '${role.name} 역할 삭제',
                            onPressed: () => _delete(context, role),
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

Future<DiscordRoleRequest?> _showRoleEditor(
  BuildContext context, {
  DiscordRole? role,
}) {
  return showDialog<DiscordRoleRequest>(
    context: context,
    builder: (context) => _GuildRoleEditorDialog(role: role),
  );
}

class _GuildRoleEditorDialog extends StatefulWidget {
  const _GuildRoleEditorDialog({this.role});

  final DiscordRole? role;

  @override
  State<_GuildRoleEditorDialog> createState() => _GuildRoleEditorDialogState();
}

class _GuildRoleEditorDialogState extends State<_GuildRoleEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.role?.name,
  );
  late final TextEditingController _color = TextEditingController(
    text: (widget.role?.color ?? 0).toRadixString(16).padLeft(6, '0'),
  );
  late BigInt _permissions = widget.role?.permissions ?? BigInt.zero;
  late bool _hoist = widget.role?.hoist ?? false;
  late bool _mentionable = widget.role?.mentionable ?? false;

  @override
  void dispose() {
    _name.dispose();
    _color.dispose();
    super.dispose();
  }

  void _setPermission(BigInt permission, bool enabled) {
    setState(() {
      _permissions = enabled
          ? _permissions | permission
          : _permissions & ~permission;
    });
  }

  void _submit() {
    final name = _name.text.trim();
    final color = int.tryParse(_color.text.trim(), radix: 16);
    if (name.isEmpty || color == null || color < 0 || color > 0xFFFFFF) {
      return;
    }
    Navigator.pop(
      context,
      DiscordRoleRequest(
        name: name,
        permissions: _permissions,
        color: color,
        hoist: _hoist,
        mentionable: _mentionable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.role == null ? '역할 만들기' : '역할 편집'),
      content: SizedBox(
        width: 460,
        child: ListView(
          shrinkWrap: true,
          children: [
            TextField(
              key: const ValueKey('role-name-field'),
              controller: _name,
              autofocus: true,
              maxLength: 100,
              decoration: const InputDecoration(labelText: '역할 이름'),
            ),
            TextField(
              controller: _color,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'RGB 색상 (hex)'),
            ),
            for (final option in _permissionOptions)
              CheckboxListTile(
                key: ValueKey('role-permission-${option.key}'),
                contentPadding: EdgeInsets.zero,
                title: Text(option.label),
                value: DiscordPermissions.has(_permissions, option.permission),
                onChanged: (value) {
                  _setPermission(option.permission, value == true);
                },
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('멤버 목록에 별도 표시'),
              value: _hoist,
              onChanged: (value) => setState(() => _hoist = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('이 역할을 멘션 가능'),
              value: _mentionable,
              onChanged: (value) => setState(() => _mentionable = value),
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

final List<({String key, String label, BigInt permission})>
_permissionOptions = [
  (
    key: 'invite',
    label: '초대 만들기',
    permission: DiscordPermissions.createInstantInvite,
  ),
  (
    key: 'channels',
    label: '채널 관리',
    permission: DiscordPermissions.manageChannels,
  ),
  (
    key: 'messages',
    label: '메시지 관리',
    permission: DiscordPermissions.manageMessages,
  ),
  (key: 'roles', label: '역할 관리', permission: DiscordPermissions.manageRoles),
  (
    key: 'threads',
    label: '스레드 관리',
    permission: DiscordPermissions.manageThreads,
  ),
  (key: 'events', label: '이벤트 관리', permission: DiscordPermissions.manageEvents),
  (
    key: 'administrator',
    label: '관리자',
    permission: DiscordPermissions.administrator,
  ),
];
