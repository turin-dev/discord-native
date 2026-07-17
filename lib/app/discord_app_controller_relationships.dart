part of 'discord_app_controller.dart';

extension DiscordAppControllerRelationships on DiscordAppController {
  Future<void> openDirectMessage(DiscordRelationship relationship) async {
    final repository = _directMessageRepository;
    if (repository == null) {
      return;
    }
    _update(_state.copyWith(peopleErrorMessage: null));
    try {
      final channel = await repository.openDirectMessage(relationship.user.id);
      _update(
        _state.copyWith(
          workspace: _state.workspace.upsertChannels([channel]),
          selectedGuildId: discordDirectMessagesGuildId,
        ),
      );
      selectChannel(channel.id);
    } on Object catch (error) {
      _showPeopleError(error);
    }
  }

  Future<void> sendFriendRequest(String username) async {
    final repository = _relationshipRepository;
    if (repository == null) {
      return;
    }
    _update(_state.copyWith(peopleErrorMessage: null));
    try {
      await repository.sendFriendRequest(username);
    } on Object catch (error) {
      _showPeopleError(error);
    }
  }

  Future<void> acceptFriendRequest(DiscordRelationship relationship) async {
    final repository = _relationshipRepository;
    if (repository == null) {
      return;
    }
    _update(_state.copyWith(peopleErrorMessage: null));
    try {
      await repository.acceptFriendRequest(relationship.user.id);
      _setRelationshipType(
        relationship.user.id,
        DiscordRelationshipType.friend,
      );
    } on Object catch (error) {
      _showPeopleError(error);
    }
  }

  Future<void> blockRelationship(DiscordRelationship relationship) async {
    final repository = _relationshipRepository;
    if (repository == null) {
      return;
    }
    _update(_state.copyWith(peopleErrorMessage: null));
    try {
      await repository.blockUser(relationship.user.id);
      _setRelationshipType(
        relationship.user.id,
        DiscordRelationshipType.blocked,
      );
    } on Object catch (error) {
      _showPeopleError(error);
    }
  }

  Future<void> removeRelationship(DiscordRelationship relationship) async {
    final repository = _relationshipRepository;
    if (repository == null) {
      return;
    }
    _update(_state.copyWith(peopleErrorMessage: null));
    try {
      await repository.removeRelationship(relationship.user.id);
      _update(
        _state.copyWith(
          peopleState: _state.peopleState.removeRelationshipById(
            relationship.user.id,
          ),
        ),
      );
    } on Object catch (error) {
      _showPeopleError(error);
    }
  }

  void _setRelationshipType(String userId, DiscordRelationshipType type) {
    _update(
      _state.copyWith(
        peopleState: _state.peopleState.setRelationshipType(userId, type),
      ),
    );
  }

  void _showPeopleError(Object error) {
    _update(_state.copyWith(peopleErrorMessage: _friendlyError(error)));
  }
}
