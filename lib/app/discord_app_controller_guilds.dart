part of 'discord_app_controller.dart';

extension DiscordAppControllerGuilds on DiscordAppController {
  Future<void> createGuildChannel(DiscordCreateChannelRequest request) async {
    final repository = _channelManagementRepository;
    final guildId = _state.selectedGuildId;
    if (repository == null ||
        guildId == null ||
        guildId == discordDirectMessagesGuildId) {
      return;
    }
    _clearGuildError();
    try {
      final channel = await repository.createChannel(
        guildId: guildId,
        request: request,
      );
      _update(
        _state.copyWith(workspace: _state.workspace.upsertChannels([channel])),
      );
      if (!channel.isCategory) {
        selectChannel(channel.id);
      }
    } on Object catch (error) {
      _showGuildError(error);
    }
  }

  Future<void> updateGuildChannel(
    String channelId,
    DiscordUpdateChannelRequest request,
  ) async {
    final repository = _channelManagementRepository;
    final channel = _state.workspace.channelById(channelId);
    if (repository == null || channel == null || channel.isPrivate) {
      return;
    }
    _clearGuildError();
    try {
      final updated = await repository.updateChannel(
        channelId: channelId,
        guildId: channel.guildId,
        request: request,
      );
      _update(
        _state.copyWith(workspace: _state.workspace.upsertChannels([updated])),
      );
    } on Object catch (error) {
      _showGuildError(error);
    }
  }

  Future<void> deleteGuildChannel(String channelId) async {
    final repository = _channelManagementRepository;
    final channel = _state.workspace.channelById(channelId);
    if (repository == null || channel == null || channel.isPrivate) {
      return;
    }
    _clearGuildError();
    try {
      await repository.deleteChannel(channelId);
      final workspace = _state.workspace.removeChannel(channelId);
      final selectedWasDeleted = _state.selectedChannelId == channelId;
      _update(
        _state.copyWith(
          workspace: workspace,
          selectedChannelId: selectedWasDeleted
              ? null
              : _state.selectedChannelId,
          messageState: selectedWasDeleted
              ? const DiscordMessageState()
              : _state.messageState,
        ),
      );
      if (selectedWasDeleted) {
        final fallbackId = _firstSelectableChannelId(
          workspace.channelsForGuild(channel.guildId),
        );
        if (fallbackId != null) {
          selectChannel(fallbackId);
        }
      }
    } on Object catch (error) {
      _showGuildError(error);
    }
  }

  Future<void> createGuildRole(DiscordRoleRequest request) async {
    final repository = _roleRepository;
    final guildId = _state.selectedGuildId;
    if (repository == null ||
        guildId == null ||
        guildId == discordDirectMessagesGuildId) {
      return;
    }
    _clearGuildError();
    try {
      final role = await repository.createRole(
        guildId: guildId,
        request: request,
      );
      _update(
        _state.copyWith(workspace: _state.workspace.upsertRole(guildId, role)),
      );
    } on Object catch (error) {
      _showGuildError(error);
    }
  }

  Future<void> updateGuildRole(
    String roleId,
    DiscordRoleRequest request,
  ) async {
    final repository = _roleRepository;
    final guildId = _state.selectedGuildId;
    if (repository == null || guildId == null || roleId == guildId) {
      return;
    }
    _clearGuildError();
    try {
      final role = await repository.updateRole(
        guildId: guildId,
        roleId: roleId,
        request: request,
      );
      _update(
        _state.copyWith(workspace: _state.workspace.upsertRole(guildId, role)),
      );
    } on Object catch (error) {
      _showGuildError(error);
    }
  }

  Future<void> updateGuildRolePositions(Map<String, int> positions) async {
    final repository = _roleRepository;
    final guildId = _state.selectedGuildId;
    if (repository == null || guildId == null) {
      return;
    }
    _clearGuildError();
    try {
      final roles = await repository.updateRolePositions(
        guildId: guildId,
        positions: positions,
      );
      _update(
        _state.copyWith(
          workspace: _state.workspace.replaceRoles(guildId, roles),
        ),
      );
    } on Object catch (error) {
      _showGuildError(error);
    }
  }

  Future<void> deleteGuildRole(String roleId) async {
    final repository = _roleRepository;
    final guildId = _state.selectedGuildId;
    if (repository == null || guildId == null || roleId == guildId) {
      return;
    }
    _clearGuildError();
    try {
      await repository.deleteRole(guildId: guildId, roleId: roleId);
      _update(
        _state.copyWith(
          workspace: _state.workspace.removeRole(guildId, roleId),
        ),
      );
    } on Object catch (error) {
      _showGuildError(error);
    }
  }

  Future<List<DiscordGuildInvite>> loadGuildInvites() async {
    final repository = _inviteRepository;
    final guildId = _state.selectedGuildId;
    if (repository == null ||
        guildId == null ||
        guildId == discordDirectMessagesGuildId) {
      return const [];
    }
    _clearGuildError();
    try {
      return await repository.listGuildInvites(guildId);
    } on Object catch (error) {
      _showGuildError(error);
      rethrow;
    }
  }

  Future<DiscordGuildInvite?> createGuildInvite(
    String channelId,
    DiscordInviteRequest request,
  ) async {
    final repository = _inviteRepository;
    if (repository == null) {
      return null;
    }
    _clearGuildError();
    try {
      return await repository.createInvite(
        channelId: channelId,
        request: request,
      );
    } on Object catch (error) {
      _showGuildError(error);
      rethrow;
    }
  }

  Future<void> deleteGuildInvite(String code) async {
    final repository = _inviteRepository;
    if (repository == null) {
      return;
    }
    _clearGuildError();
    try {
      await repository.deleteInvite(code);
    } on Object catch (error) {
      _showGuildError(error);
      rethrow;
    }
  }

  Future<List<DiscordScheduledEvent>> loadScheduledEvents() async {
    final repository = _scheduledEventRepository;
    final guildId = _state.selectedGuildId;
    if (repository == null ||
        guildId == null ||
        guildId == discordDirectMessagesGuildId) {
      return const [];
    }
    _clearGuildError();
    try {
      final events = await repository.listEvents(guildId);
      _update(
        _state.copyWith(
          workspace: _state.workspace.replaceScheduledEvents(guildId, events),
        ),
      );
      return events;
    } on Object catch (error) {
      _showGuildError(error);
      rethrow;
    }
  }

  Future<DiscordScheduledEvent?> createScheduledEvent(
    DiscordExternalEventRequest request,
  ) async {
    final repository = _scheduledEventRepository;
    final guildId = _state.selectedGuildId;
    if (repository == null || guildId == null) {
      return null;
    }
    _clearGuildError();
    try {
      final event = await repository.createExternalEvent(
        guildId: guildId,
        request: request,
      );
      _update(
        _state.copyWith(
          workspace: _state.workspace.upsertScheduledEvent(event),
        ),
      );
      return event;
    } on Object catch (error) {
      _showGuildError(error);
      rethrow;
    }
  }

  Future<DiscordScheduledEvent?> updateScheduledEvent(
    String eventId,
    DiscordExternalEventRequest request, {
    DiscordScheduledEventStatus? status,
  }) async {
    final repository = _scheduledEventRepository;
    final guildId = _state.selectedGuildId;
    if (repository == null || guildId == null) {
      return null;
    }
    _clearGuildError();
    try {
      final event = await repository.updateExternalEvent(
        guildId: guildId,
        eventId: eventId,
        request: request,
        status: status,
      );
      _update(
        _state.copyWith(
          workspace: _state.workspace.upsertScheduledEvent(event),
        ),
      );
      return event;
    } on Object catch (error) {
      _showGuildError(error);
      rethrow;
    }
  }

  Future<void> deleteScheduledEvent(String eventId) async {
    final repository = _scheduledEventRepository;
    final guildId = _state.selectedGuildId;
    if (repository == null || guildId == null) {
      return;
    }
    _clearGuildError();
    try {
      await repository.deleteEvent(guildId: guildId, eventId: eventId);
      _update(
        _state.copyWith(
          workspace: _state.workspace.removeScheduledEvent(eventId),
        ),
      );
    } on Object catch (error) {
      _showGuildError(error);
      rethrow;
    }
  }

  void _clearGuildError() {
    _update(_state.copyWith(guildErrorMessage: null));
  }

  void _showGuildError(Object error) {
    _update(_state.copyWith(guildErrorMessage: _friendlyError(error)));
  }
}
