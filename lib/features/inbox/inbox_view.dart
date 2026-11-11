import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/friend_repository.dart';
import '../../data/inbox_repository.dart';
import '../../session/session_controller.dart';
import '../../widgets/app_loader.dart';
import '../friends/friends_view.dart';
import 'inbox_controller.dart';
import 'inbox_kind.dart';
import '../../widgets/compact_buttons.dart';

/// The in-app inbox (opened from the bell on Today). No push yet: it shows
/// what zinc has when opened, newest first.
class InboxView extends StatelessWidget {
  const InboxView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) {
        final session = ctx.read<SessionController>();
        final api = session.auth.makeApiClient();
        return InboxController(
          InboxRepository(api),
          FriendRepository(api),
          session.userId ?? '',
        )..load();
      },
      child: const _InboxScaffold(),
    );
  }
}

class _InboxScaffold extends StatelessWidget {
  const _InboxScaffold();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<InboxController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        actions: [
          if (c.phase == InboxPhase.ready && c.hasUnread)
            TextButton(
              onPressed: c.markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: switch (c.phase) {
        InboxPhase.loading => const AppLoader(),
        InboxPhase.error => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  c.error?.displayMessage ?? 'Could not load your inbox',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: c.load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
        InboxPhase.ready => _List(c: c),
      },
    );
  }
}

class _List extends StatelessWidget {
  final InboxController c;
  const _List({required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (c.actionError != null)
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
          if (c.items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  Text('Nothing here yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Friend requests and news from friends show up here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < c.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _Item(n: c.items[i], c: c),
                  ],
                ],
              ),
            ),
          if (c.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: c.loadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      )
                    : TextButton(
                        onPressed: c.loadMore,
                        child: const Text('Load more'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final InboxNotificationRes n;
  final InboxController c;
  const _Item({required this.n, required this.c});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = inboxKindOf(n);
    final muted = theme.colorScheme.onSurfaceVariant;
    final icon = switch (kind) {
      FriendRequestNotice() => Icons.person_add_alt_1_outlined,
      FriendAcceptedNotice() => Icons.people_outline,
      FriendMissedNotice() => Icons.campaign_outlined,
      PlainNotice() => Icons.notifications_none,
    };
    final answer = c.answerFor(n.id);
    final busy = c.isBusy(n.id);

    return InkWell(
      onTap: () {
        c.markRead(n);
        if (kind is FriendAcceptedNotice) {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const FriendsView()));
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: n.read ? muted : theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: n.read
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!n.read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.body,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                  if (n.createdAtUtc != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _ago(n.createdAtUtc!, DateTime.now().toUtc(), context),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                  if (kind is FriendRequestNotice) ...[
                    const SizedBox(height: 8),
                    if (answer != null)
                      Text(
                        answer == RequestAnswer.accepted
                            ? 'You’re now friends'
                            : 'Declined',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: muted,
                        ),
                      )
                    else if (busy)
                      const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      CompactButtons(
                        child: Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: () =>
                                  c.answer(n, kind.fromUserId, accept: true),
                              child: const Text('Accept'),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  c.answer(n, kind.fromUserId, accept: false),
                              child: const Text('Decline'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ago(DateTime at, DateTime now, BuildContext context) {
    final d = now.difference(at);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} d ago';
    return MaterialLocalizations.of(context).formatMediumDate(at.toLocal());
  }
}
