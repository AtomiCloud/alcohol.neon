import 'dart:async';

import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../dev/dev_config_view.dart';
import '../../core/problem.dart';
import '../../generated/zinc/models/user_principal_res.dart';
import '../../session/session_controller.dart';
import '../settings/settings_view.dart';

/// M5 — the profile screen (mirrors argon's `profile.tsx` field-card layout, minus
/// the web-only TokensSection / developer / append-details blocks). Header shows
/// name + email from the id-token claims; the account fields (username, email
/// verified, active) come from `GET /User/Me/All` since `UserClaims` doesn't carry
/// username / emailVerified. Hosts the 'Manage settings' entry point and Sign out.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  UserClaims? _claims;
  UserPrincipalRes? _user;
  bool _loading = true;
  Problem? _error;

  // Account-deletion action state (separate from the page-load _error above).
  bool _deleting = false;
  Problem? _deleteError;

  // Secret dev-menu entry: 7 taps on the name, then the dev password.
  int _nameTaps = 0;
  Timer? _tapReset;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tapReset?.cancel();
    super.dispose();
  }

  void _onNameTap() {
    _tapReset?.cancel();
    _tapReset = Timer(const Duration(seconds: 2), () => _nameTaps = 0);
    if (++_nameTaps >= 7) {
      _nameTaps = 0;
      _tapReset?.cancel();
      openDevConfig(context);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthService>();
    final session = context.read<SessionController>();

    final claims = await auth.claims();
    final meRes = await session.users.me();
    if (!mounted) return;

    switch (meRes) {
      case Ok(:final value):
        setState(() {
          _claims = claims;
          _user = value.principal;
          _loading = false;
        });
      case Err(:final problem):
        setState(() {
          _claims = claims;
          _loading = false;
          _error = problem;
        });
    }
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsView()));
  }

  // AuthService is a ChangeNotifier and RootView reacts to its status — just sign
  // out and let the shell swap to the signed-out experience (no manual nav).
  void _signOut() => context.read<AuthService>().signOut();

  /// Permanently deletes the account after an explicit irreversible confirmation.
  /// On success we sign out — RootView reacts to the status change and swaps to the
  /// signed-in/locked-out shell. A 409 means deletion is blocked by outstanding debt;
  /// we surface the server's message inline rather than a raw error.
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and sign-in — your profile, habits, '
          'history, vacations, freeze balances, payment details and settings. There '
          'is no grace period and it cannot be undone.\n\n'
          'Past charity-donation records are kept for accounting, with your personal '
          'details removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final session = context.read<SessionController>();
    final auth = context.read<AuthService>();
    setState(() {
      _deleting = true;
      _deleteError = null;
    });

    final res = await session.users.deleteMe();
    if (!mounted) return;

    switch (res) {
      case Ok():
        // Account + Logto identity are gone server-side; clear the local session.
        // RootView swaps to the signed-out shell, disposing this screen.
        auth.signOut();
      case Err(:final problem):
        setState(() {
          _deleting = false;
          _deleteError = problem;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const AppLoader()
          : _error != null
          ? _ErrorRetry(problem: _error!, onRetry: _load)
          : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final user = _user;
    final displayName =
        _claims?.name ??
        user?.username ??
        _claims?.email ??
        user?.email ??
        'User';
    final email = _claims?.email ?? user?.email ?? '';
    final initial = (user?.username ?? email).trim().isEmpty
        ? 'U'
        : (user?.username ?? email).trim()[0].toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                initial,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _onNameTap,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      displayName,
                      style: theme.textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _FieldCard(
          label: 'Username',
          value: (user?.username ?? '').isEmpty ? '—' : user!.username!,
          subtitle: 'Your unique handle used across the app.',
        ),
        _FieldCard(
          label: 'Email',
          value: email.isEmpty ? '—' : email,
          subtitle: 'Used for sign-in and notifications.',
        ),
        _FieldCard(
          label: 'Email verified',
          value: user == null ? '—' : (user.emailVerified ? 'Yes' : 'No'),
          subtitle: 'Whether your email address has been verified.',
        ),
        _FieldCard(
          label: 'Active',
          value: user == null ? '—' : (user.active ? 'Yes' : 'No'),
          subtitle: 'Whether your account is active.',
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Manage settings'),
            subtitle: const Text('Timezone, default charity, payment consent'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openSettings,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _deleting ? null : _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _deleting ? null : _deleteAccount,
          icon: _deleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_forever),
          label: Text(_deleting ? 'Deleting…' : 'Delete account'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            side: BorderSide(color: theme.colorScheme.error),
          ),
        ),
        if (_deleteError != null) ...[
          const SizedBox(height: 12),
          Text(
            _deleteError!.status == 409
                ? (_deleteError!.detail ??
                      'You have an outstanding debt. Please settle it before '
                          'deleting your account.')
                : (_deleteError!.detail ?? _deleteError!.title),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// Read-only profile field (mirrors argon's disabled-input FieldCard).
class _FieldCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  const _FieldCard({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final Problem problem;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.problem, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(problem.title, style: Theme.of(context).textTheme.titleMedium),
            if (problem.detail != null) ...[
              const SizedBox(height: 8),
              Text(problem.detail!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
