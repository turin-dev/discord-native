import 'dart:async';

import 'package:discord_native/core/auth/discord_account_repository.dart';
import 'package:discord_native/core/auth/token_validator.dart';
import 'package:flutter/material.dart';

typedef ConnectCallback = Future<void> Function(String token);
typedef SelectAccountCallback = Future<void> Function(String accountId);

final class LoginFormState {
  const LoginFormState({this.token = '', this.errorMessage});

  final String token;
  final String? errorMessage;

  LoginFormState copyWith({
    String? token,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoginFormState(
      token: token ?? this.token,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.onConnect,
    this.errorMessage,
    this.isConnecting = false,
    this.savedAccounts = const [],
    this.onSelectAccount,
    super.key,
  });

  final ConnectCallback onConnect;
  final String? errorMessage;
  final bool isConnecting;
  final List<SavedDiscordAccount> savedAccounts;
  final SelectAccountCallback? onSelectAccount;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final ValueNotifier<LoginFormState> _form = ValueNotifier(
    const LoginFormState(),
  );

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      final token = TokenValidator.validate(_form.value.token);
      _form.value = _form.value.copyWith(clearError: true);
      await widget.onConnect(token);
    } on InvalidTokenException catch (error) {
      _form.value = _form.value.copyWith(errorMessage: error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111214),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ValueListenableBuilder(
              valueListenable: _form,
              builder: (context, form, _) => _LoginForm(
                form: form,
                externalErrorMessage: widget.errorMessage,
                isConnecting: widget.isConnecting,
                savedAccounts: widget.savedAccounts,
                onSelectAccount: widget.onSelectAccount,
                onChanged: (token) {
                  _form.value = form.copyWith(token: token, clearError: true);
                },
                onConnect: _connect,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.form,
    required this.externalErrorMessage,
    required this.isConnecting,
    required this.onChanged,
    required this.onConnect,
    required this.savedAccounts,
    required this.onSelectAccount,
  });

  final LoginFormState form;
  final String? externalErrorMessage;
  final bool isConnecting;
  final ValueChanged<String> onChanged;
  final VoidCallback onConnect;
  final List<SavedDiscordAccount> savedAccounts;
  final SelectAccountCallback? onSelectAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.discord, size: 56, color: Color(0xFF5865F2)),
        const SizedBox(height: 24),
        const Text(
          'Discord Native',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const _RiskNotice(),
        if (savedAccounts.isNotEmpty && onSelectAccount != null) ...[
          const SizedBox(height: 16),
          _SavedAccountPicker(
            accounts: savedAccounts,
            enabled: !isConnecting,
            onSelect: onSelectAccount!,
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          obscureText: true,
          onChanged: onChanged,
          onSubmitted: (_) => onConnect(),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Discord 사용자 토큰',
            errorText: form.errorMessage ?? externalErrorMessage,
            filled: true,
            fillColor: const Color(0xFF1E1F22),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: isConnecting ? null : onConnect,
          child: Text(isConnecting ? '연결 중…' : '연결'),
        ),
      ],
    );
  }
}

class _SavedAccountPicker extends StatelessWidget {
  const _SavedAccountPicker({
    required this.accounts,
    required this.enabled,
    required this.onSelect,
  });

  final List<SavedDiscordAccount> accounts;
  final bool enabled;
  final SelectAccountCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '저장 계정으로 연결',
          style: TextStyle(color: Color(0xFFB5BAC1), fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final account in accounts)
              OutlinedButton.icon(
                onPressed: enabled
                    ? () => unawaited(onSelect(account.id))
                    : null,
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(account.label),
              ),
          ],
        ),
      ],
    );
  }
}

class _RiskNotice extends StatelessWidget {
  const _RiskNotice();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: Color(0xFF3B2F18),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '계정 정지 위험',
              style: TextStyle(
                color: Color(0xFFF0B232),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '비공식 사용자 계정 클라이언트는 Discord ToS를 위반할 수 '
              '있습니다. 부계정 사용을 권장합니다.',
              style: TextStyle(color: Color(0xFFF0B232), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
