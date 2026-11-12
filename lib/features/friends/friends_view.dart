import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../data/friend_repository.dart';
import '../../session/session_controller.dart';
import '../../widgets/app_loader.dart';
import 'friend_relation.dart';
import 'friends_controller.dart';
import '../../widgets/compact_buttons.dart';

/// Profile → Friends: search by username, answer requests, invite with a
/// link or code, and manage the friend list.
class FriendsView extends StatelessWidget {
  const FriendsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) {
        final session = ctx.read<SessionController>();
        return FriendsController(
          FriendRepository(session.auth.makeApiClient()),
          session.userId ?? '',
        )..load();
      },
      child: const _FriendsScaffold(),
    );
  }
}

class _FriendsScaffold extends StatelessWidget {
  const _FriendsScaffold();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<FriendsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: switch (c.phase) {
        FriendsPhase.loading => const AppLoader(),
        FriendsPhase.error => _ErrorRetry(
          message: c.error?.displayMessage ?? 'Could not load friends',
          onRetry: c.load,
        ),
        FriendsPhase.ready => _Content(c: c),
      },
    );
  }
}

class _Content extends StatelessWidget {
  final FriendsController c;
  const _Content({required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incoming = c.requests.incoming;
    final outgoing = c.requests.outgoing;
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Find people',
              hintText: 'Search by username',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: c.search,
          ),
          if (c.query.isNotEmpty) _SearchResults(c: c),
          if (c.actionError != null) ...[
            const SizedBox(height: 12),
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.onErrorContainer,
                ),
                title: Text(
                  c.actionError!.displayMessage,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  color: theme.colorScheme.onErrorContainer,
                  onPressed: c.clearActionError,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _InviteCard(c: c),
          if (incoming.isNotEmpty) ...[
            const _Header('Requests'),
            Card(
              child: Column(
                children: [
                  for (final r in incoming)
                    _PersonTile(
                      username: r.username,
                      subtitle: 'Wants to be friends',
                      busy: c.isBusy(r.userId),
                      actions: [
                        TextButton(
                          onPressed: () => c.deleteRequest(r.userId),
                          child: const Text('Decline'),
                        ),
                        FilledButton(
                          onPressed: () => c.accept(r.userId),
                          child: const Text('Accept'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          if (outgoing.isNotEmpty) ...[
            const _Header('Sent'),
            Card(
              child: Column(
                children: [
                  for (final r in outgoing)
                    _PersonTile(
                      username: r.username,
                      subtitle: 'Request sent',
                      busy: c.isBusy(r.userId),
                      actions: [
                        TextButton(
                          onPressed: () => c.deleteRequest(r.userId),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          _Header('Friends (${c.friends.length})'),
          if (c.friends.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('No friends yet'),
                subtitle: const Text(
                  'Search for someone’s username or send them an invite.',
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final f in c.friends)
                    _PersonTile(
                      username: f.username,
                      subtitle: f.sinceUtc == null
                          ? null
                          : 'Friends since '
                                '${MaterialLocalizations.of(context).formatMediumDate(f.sinceUtc!.toLocal())}',
                      busy: c.isBusy(f.userId),
                      actions: [
                        IconButton(
                          tooltip: 'Remove friend',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () => _confirmRemove(context, f),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, FriendRes f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${f.username}?'),
        content: const Text(
          'You stop being friends. They won’t be told when you miss a habit '
          'any more.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await c.remove(f.userId);
  }
}

class _SearchResults extends StatelessWidget {
  final FriendsController c;
  const _SearchResults({required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final Widget body;
    if (c.query.length < 2) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Type at least 2 characters.', style: muted),
      );
    } else if (c.searching) {
      body = const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      );
    } else if (c.searchError != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          c.searchError!.displayMessage,
          style: muted?.copyWith(color: theme.colorScheme.error),
        ),
      );
    } else if (c.results.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No one with a username starting “${c.query}”.',
          style: muted,
        ),
      );
    } else {
      body = Column(
        children: [
          for (final r in c.results)
            _PersonTile(
              username: r.username,
              busy: c.isBusy(r.userId),
              actions: [
                switch (friendActionFor(r.relation)) {
                  FriendAction.add => FilledButton.tonal(
                    onPressed: () => c.sendRequest(r.userId),
                    child: const Text('Add'),
                  ),
                  FriendAction.cancel => TextButton(
                    onPressed: () => c.deleteRequest(r.userId),
                    child: const Text('Cancel request'),
                  ),
                  FriendAction.accept => FilledButton(
                    onPressed: () => c.accept(r.userId),
                    child: const Text('Accept'),
                  ),
                  FriendAction.none => Text(
                    r.relation == 'friend' ? 'Friends' : '',
                    style: muted,
                  ),
                },
              ],
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(child: body),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final FriendsController c;
  const _InviteCard({required this.c});

  Future<void> _create(BuildContext context) async {
    final res = await c.createInvite();
    if (!context.mounted) return;
    switch (res) {
      case Ok(:final value):
        await _copy(context, inviteLink(value.code));
      case Err(:final problem):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(problem.displayMessage)));
    }
  }

  Future<void> _copy(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite link copied. Send it to a friend.')),
    );
  }

  Future<void> _enterCode(BuildContext context) async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _InviteCodeDialog(),
    );
    if (code == null || !context.mounted) return;
    final res = await c.acceptInvite(code);
    if (!context.mounted) return;
    final message = switch (res) {
      Ok(:final value) => 'You and ${value.username} are now friends.',
      Err(:final problem) when problem.status == 404 =>
        'That invite doesn’t exist or has expired. Ask for a new one.',
      Err(:final problem) when problem.status == 400 =>
        'That’s your own invite. Send it to a friend instead.',
      Err(:final problem) => problem.displayMessage,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invite = c.invite;
    final expires = invite?.expiresAtUtc?.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invite a friend', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Send a link they can open, or a code they can enter here. '
              'It works for 7 days.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (invite != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                inviteLink(invite.code),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Code ${invite.code}'
                '${expires == null ? '' : ' · expires ${MaterialLocalizations.of(context).formatMediumDate(expires)}'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (invite == null)
                  FilledButton.icon(
                    onPressed: c.inviting ? null : () => _create(context),
                    icon: c.inviting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: const Text('Create invite link'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _copy(context, inviteLink(invite.code)),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy link'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _enterCode(context),
                  icon: const Icon(Icons.input),
                  label: const Text('Enter a code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pops the cleaned code (see [inviteCodeFrom]), or null on cancel.
class _InviteCodeDialog extends StatefulWidget {
  const _InviteCodeDialog();

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text;
    if (t != null && mounted) setState(() => _text.text = t.trim());
  }

  void _submit() {
    final code = inviteCodeFrom(_text.text);
    if (code == null) {
      setState(() => _error = 'Enter the code or paste the invite link');
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter an invite'),
      content: TextField(
        controller: _text,
        autofocus: true,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: 'Code or lazytax.club/f/… link',
          errorText: _error,
          suffixIcon: IconButton(
            tooltip: 'Paste',
            icon: const Icon(Icons.content_paste),
            onPressed: _paste,
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add friend')),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  final String username;
  final String? subtitle;
  final bool busy;
  final List<Widget> actions;
  const _PersonTile({
    required this.username,
    this.subtitle,
    required this.busy,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = username.isEmpty ? 'Someone' : username;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          name[0].toUpperCase(),
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : CompactButtons(
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
