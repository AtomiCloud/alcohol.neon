import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/friend_repository.dart';
import '../../data/inbox_repository.dart';
import '../../session/session_controller.dart';
import '../../theme/glass.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_page.dart';
import '../friends/friends_view.dart';
import 'inbox_controller.dart';
import 'inbox_kind.dart';

/// The in-app inbox (opened from the bell on Today). No push yet: it shows
/// what zinc has when opened, newest first, grouped into Today and Earlier.
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
    final ready = c.phase == InboxPhase.ready;
    return GlassPage(
      title: 'Inbox',
      onRefresh: ready ? c.load : null,
      actions: [
        if (ready && c.hasUnread)
          TextButton(
            onPressed: c.markAllRead,
            style: TextButton.styleFrom(
              foregroundColor: GlassTokens.of(context).accent,
            ),
            child: const Text('Mark all read'),
          ),
      ],
      children: switch (c.phase) {
        InboxPhase.loading => const [SizedBox(height: 320, child: AppLoader())],
        InboxPhase.error => [
          GlassBanner(
            icon: Icons.cloud_off_rounded,
            title: c.error?.displayMessage ?? 'Could not load your inbox',
            error: true,
            action: TextButton(onPressed: c.load, child: const Text('Retry')),
          ),
        ],
        InboxPhase.ready => _list(context, c),
      },
    );
  }

  List<Widget> _list(BuildContext context, InboxController c) {
    final now = DateTime.now();
    bool isToday(InboxNotificationRes n) {
      final at = n.createdAtUtc?.toLocal();
      return at != null && DateUtils.isSameDay(at, now);
    }

    final today = c.items.where(isToday).toList();
    final earlier = c.items.where((n) => !isToday(n)).toList();
    return [
      if (c.actionError case final error?)
        GlassBanner(
          icon: Icons.error_outline_rounded,
          title: error.displayMessage,
          error: true,
          action: IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded),
            onPressed: c.clearActionError,
          ),
        ),
      if (c.items.isEmpty) ...[const SizedBox(height: 8), const _Empty()],
      if (today.isNotEmpty)
        GlassSection(
          title: 'Today',
          dividerIndent: 66,
          children: [for (final n in today) _Item(n: n, c: c)],
        ),
      if (earlier.isNotEmpty)
        GlassSection(
          title: 'Earlier',
          dividerIndent: 66,
          children: [for (final n in earlier) _Item(n: n, c: c)],
        ),
      if (c.hasMore)
        Padding(
          padding: const EdgeInsets.only(top: 12),
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
    ];
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    return Glass(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: t.track, shape: BoxShape.circle),
            child: const SizedBox.square(
              dimension: 52,
              child: Icon(Icons.inbox_outlined, size: 26),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing here yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Friend requests and news from friends show up here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
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
    final t = GlassTokens.of(context);
    final kind = inboxKindOf(n);
    final (icon, tint) = switch (kind) {
      FriendRequestNotice() => (Icons.person_add_alt_1_rounded, t.accent),
      FriendAcceptedNotice() => (Icons.group_rounded, const Color(0xFF0EA5E9)),
      FriendMissedNotice() => (Icons.campaign_rounded, const Color(0xFFF59E0B)),
      PlainNotice() => (Icons.notifications_rounded, t.muted),
    };
    final answer = c.answerFor(n.id);
    final busy = c.isBusy(n.id);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 38,
              child: Icon(icon, size: 20, color: tint),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: n.read ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
                if (n.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                  ),
                ],
                if (n.createdAtUtc != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _ago(n.createdAtUtc!, DateTime.now().toUtc(), context),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
                  ),
                ],
                if (kind is FriendRequestNotice) ...[
                  const SizedBox(height: 10),
                  if (answer != null)
                    Text(
                      answer == RequestAnswer.accepted
                          ? 'You’re now friends'
                          : 'Declined',
                      style: theme.textTheme.labelLarge,
                    )
                  else if (busy)
                    const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Row(
                      children: [
                        GlassButton(
                          label: 'Accept',
                          compact: true,
                          onPressed: () =>
                              c.answer(n, kind.fromUserId, accept: true),
                        ),
                        const SizedBox(width: 8),
                        GlassButton(
                          label: 'Decline',
                          compact: true,
                          secondary: true,
                          onPressed: () =>
                              c.answer(n, kind.fromUserId, accept: false),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
          if (!n.read)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 6),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: t.accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
    return Semantics(
      button: true,
      child: Pressable(
        scale: 0.98,
        onTap: () {
          c.markRead(n);
          if (kind is FriendAcceptedNotice) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FriendsView()));
          }
        },
        child: content,
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
