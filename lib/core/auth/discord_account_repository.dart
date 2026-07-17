import 'dart:convert';

import 'package:discord_native/core/auth/secure_token_repository.dart';

final class SavedDiscordAccount {
  const SavedDiscordAccount({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarHash,
  });

  factory SavedDiscordAccount.fromJson(Map<String, Object?> json) {
    return SavedDiscordAccount(
      id: _requiredString(json['id'], 'account.id'),
      username: _requiredString(json['username'], 'account.username'),
      displayName: _optionalString(json['displayName']),
      avatarHash: _optionalString(json['avatarHash']),
    );
  }

  final String id;
  final String username;
  final String? displayName;
  final String? avatarHash;

  String get label => displayName ?? username;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'username': username,
      'displayName': displayName,
      'avatarHash': avatarHash,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is SavedDiscordAccount &&
        other.id == id &&
        other.username == username &&
        other.displayName == displayName &&
        other.avatarHash == avatarHash;
  }

  @override
  int get hashCode => Object.hash(id, username, displayName, avatarHash);
}

abstract interface class DiscordAccountRepository {
  Future<List<SavedDiscordAccount>> loadAll();

  Future<String?> loadToken(String accountId);

  Future<void> save(SavedDiscordAccount account, String token);

  Future<void> remove(String accountId);

  Future<String?> loadSelectedId();

  Future<void> select(String? accountId);
}

final class SecureDiscordAccountRepository implements DiscordAccountRepository {
  const SecureDiscordAccountRepository(this._storage);

  static const _accountsKey = 'discord_accounts';
  static const _selectedKey = 'discord_selected_account';
  static const _tokenPrefix = 'discord_account_token_';

  final SecretStorage _storage;

  @override
  Future<List<SavedDiscordAccount>> loadAll() async {
    final encoded = await _storage.read(key: _accountsKey);
    if (encoded == null || encoded.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) {
        return const [];
      }
      return List.unmodifiable(
        decoded.map((item) {
          if (item is! Map) {
            throw const FormatException('계정 인덱스 형식이 올바르지 않습니다.');
          }
          return SavedDiscordAccount.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          );
        }),
      );
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<String?> loadToken(String accountId) {
    return _storage.read(key: _tokenKey(accountId));
  }

  @override
  Future<void> save(SavedDiscordAccount account, String token) async {
    if (token.trim().isEmpty) {
      throw const FormatException('계정 토큰이 비어 있습니다.');
    }
    final accounts = await loadAll();
    final next = [
      for (final current in accounts)
        if (current.id == account.id) account else current,
      if (!accounts.any((current) => current.id == account.id)) account,
    ];
    await _storage.write(key: _accountsKey, value: jsonEncode(next));
    await _storage.write(key: _tokenKey(account.id), value: token);
  }

  @override
  Future<void> remove(String accountId) async {
    final accounts = await loadAll();
    final next = accounts.where((account) => account.id != accountId).toList();
    await _storage.write(key: _accountsKey, value: jsonEncode(next));
    await _storage.delete(key: _tokenKey(accountId));
    if (await loadSelectedId() == accountId) {
      await select(null);
    }
  }

  @override
  Future<String?> loadSelectedId() {
    return _storage.read(key: _selectedKey);
  }

  @override
  Future<void> select(String? accountId) async {
    if (accountId == null) {
      await _storage.delete(key: _selectedKey);
      return;
    }
    _validateId(accountId);
    await _storage.write(key: _selectedKey, value: accountId);
  }

  String _tokenKey(String accountId) {
    _validateId(accountId);
    return '$_tokenPrefix${Uri.encodeComponent(accountId)}';
  }
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field 값이 올바르지 않습니다.');
  }
  return value;
}

String? _optionalString(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

void _validateId(String accountId) {
  if (accountId.trim().isEmpty || accountId.length > 128) {
    throw const FormatException('계정 ID가 올바르지 않습니다.');
  }
}
