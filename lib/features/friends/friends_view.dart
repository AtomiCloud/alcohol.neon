import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/problem.dart';
import '../../data/friend_repository.dart';
import '../../session/session_controller.dart';
import '../../theme/glass.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/glass_page.dart';
import 'friend_relation.dart';
import 'friends_controller.dart';

/// Profile → Friends: search by username, answer requests, invite with a
/// link or code, and manage the friend list. Requests come first because
/// they need an answer; typing in the search bar shows only the results.
class FriendsView extends StatelessWidget {
  /// From an invite link: accepted as soon as the screen opens.
  final String? inviteCode;
  const FriendsView({super.key, this.inviteCode});

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
      child: _FriendsScaffold(inviteCode: inviteCode),
    );
  }
}

/// The toast after accepting an invite code.
String inviteResultMessage(Result<String> res) => switch (res) {
  Ok(value: 'friend') => 'You’re now friends.',
  Ok() => 'Friend request sent. You’ll be friends once they accept.',
  Err(:final problem) when problem.status == 404 =>
    'That invite link isn’t valid. Ask your friend to send it again.',
  Err(:final problem) when problem.status == 400 =>
    'That’s your own invite. Send it to a friend instead.',
  Err(:final problem) => problem.displayMessage,
};

class _FriendsScaffold extends StatefulWidget {
  final String? inviteCode;
  const _FriendsScaffold({this.inviteCode});

  @override
  State<_FriendsScaffold> createState() => _FriendsScaffoldState();
}

class _FriendsScaffoldState extends State<_FriendsScaffold> {
  @override
  void initState() {
    super.initState();
    final code = widget.inviteCode;
    if (code == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final res = await context.read<FriendsController>().acceptInvite(code);
      if (!mounted) return;
      showGlassToast(context, inviteResultMessage(res));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<FriendsController>();
    return GlassPage(
      title: 'Friends',
      onRefresh: c.phase == FriendsPhase.ready ? c.load : null,
      children: switch (c.phase) {
        FriendsPhase.loading => const [
          SizedBox(height: 320, child: AppLoader()),
        ],
        FriendsPhase.error => [
          GlassBanner(
            icon: Icons.cloud_off_rounded,
            title: c.error?.displayMessage ?? 'Could not load friends',
            error: true,
            action: TextButton(onPressed: c.load, child: const Text('Retry')),
          ),
        ],
        FriendsPhase.ready => _content(context, c),
      },
    );
  }

  List<Widget> _content(BuildContext context, FriendsController c) {
    final incoming = c.requests.incoming;
    final outgoing = c.requests.outgoing;
    return [
      const SizedBox(height: 4),
      GlassSearchField(hint: 'Find people by username', onChanged: c.search),
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
      if (c.query.isNotEmpty)
        _SearchResults(c: c)
      else ...[
        if (incoming.isNotEmpty)
          GlassSection(
            title: 'Requests',
            dividerIndent: 66,
            children: [
              for (final r in incoming)
                _Person(
                  username: r.username,
                  subtitle: 'Wants to be friends',
                  busy: c.isBusy(r.userId),
                  actions: [
                    GlassButton(
                      label: 'Accept',
                      compact: true,
                      onPressed: () => c.accept(r.userId),
                    ),
                    const SizedBox(width: 6),
                    GlassButton(
                      label: 'Decline',
                      compact: true,
                      secondary: true,
                      onPressed: () => c.deleteRequest(r.userId),
                    ),
                  ],
                ),
            ],
          ),
        const GlassHeading('Invite'),
        _InviteCard(c: c),
        if (c.friends.isEmpty) ...[
          const SizedBox(height: 16),
          const _NoFriends(),
        ] else
          GlassSection(
            title: 'Friends (${c.friends.length})',
            dividerIndent: 66,
            children: [
              for (final f in c.friends)
                _Person(
                  username: f.username,
                  subtitle: f.sinceUtc == null
                      ? null
                      : 'Friends since '
                            '${MaterialLocalizations.of(context).formatMediumDate(f.sinceUtc!.toLocal())}',
                  busy: c.isBusy(f.userId),
                  actions: [_MoreButton(friend: f, c: c)],
                ),
            ],
          ),
        if (outgoing.isNotEmpty)
          GlassSection(
            title: 'Sent',
            dividerIndent: 66,
            children: [
              for (final r in outgoing)
                _Person(
                  username: r.username,
                  subtitle: 'Request sent',
                  busy: c.isBusy(r.userId),
                  actions: [
                    GlassButton(
                      label: 'Cancel',
                      compact: true,
                      secondary: true,
                      onPressed: () => c.deleteRequest(r.userId),
                    ),
                  ],
                ),
            ],
          ),
      ],
    ];
  }
}

/// A friend's menu: an action sheet on iOS, a popup menu on Android. Either
/// way, removing asks first.
class _MoreButton extends StatelessWidget {
  final FriendRes friend;
  final FriendsController c;
  const _MoreButton({required this.friend, required this.c});

  Future<void> _remove(BuildContext context) async {
    final ok = await showGlassConfirm(
      context,
      title: 'Remove ${friend.username}?',
      message:
          'You stop being friends. They won’t be told when you miss a habit '
          'any more.',
      confirmLabel: 'Remove friend',
    );
    if (ok) await c.remove(friend.userId);
  }

  @override
  Widget build(BuildContext context) {
    final muted = GlassTokens.of(context).muted;
    final tooltip = 'More for ${friend.username}';
    if (isCupertino(context)) {
      return IconButton(
        tooltip: tooltip,
        icon: Icon(Icons.more_horiz_rounded, color: muted),
        onPressed: () => _remove(context),
      );
    }
    return PopupMenuButton<void>(
      tooltip: tooltip,
      icon: Icon(Icons.more_vert_rounded, color: muted),
      itemBuilder: (_) => [
        PopupMenuItem(
          onTap: () => _remove(context),
          child: const Text('Remove friend'),
        ),
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  final FriendsController c;
  const _SearchResults({required this.c});

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    Widget note(String text, {bool error = false}) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Text(
        text,
        style: TextStyle(
          color: error ? Theme.of(context).colorScheme.error : t.muted,
        ),
      ),
    );
    if (c.query.length < 2) return note('Type at least 2 characters.');
    if (c.searching) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (c.searchError case final error?) {
      return note(error.displayMessage, error: true);
    }
    if (c.results.isEmpty) {
      return note('No one with a username starting “${c.query}”.');
    }
    return GlassSection(
      title: 'People',
      dividerIndent: 66,
      children: [
        for (final r in c.results)
          _Person(
            username: r.username,
            subtitle: switch (r.relation) {
              'friend' => 'Friends',
              'outgoing' => 'Request sent',
              'incoming' => 'Wants to be friends',
              _ => null,
            },
            busy: c.isBusy(r.userId),
            actions: [
              ?switch (friendActionFor(r.relation)) {
                FriendAction.add => GlassButton(
                  label: 'Add',
                  compact: true,
                  onPressed: () => c.sendRequest(r.userId),
                ),
                FriendAction.cancel => GlassButton(
                  label: 'Cancel',
                  compact: true,
                  secondary: true,
                  onPressed: () => c.deleteRequest(r.userId),
                ),
                FriendAction.accept => GlassButton(
                  label: 'Accept',
                  compact: true,
                  onPressed: () => c.accept(r.userId),
                ),
                FriendAction.none => null,
              },
            ],
          ),
      ],
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
        await _share(context, inviteLink(value.code));
      case Err(:final problem):
        showGlassToast(context, problem.displayMessage);
    }
  }

  /// Opens the system share sheet; the link's preview card comes from the
  /// invite page's Open Graph tags.
  Future<void> _share(BuildContext context, String link) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        text: 'Be my LazyTax friend: $link',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _copy(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    showGlassToast(context, 'Invite link copied. Send it to a friend.');
  }

  Future<void> _enterCode(BuildContext context) async {
    final code = await showGlassSheet<String>(
      context,
      (_) => const _InviteCodeSheet(),
    );
    if (code == null || !context.mounted) return;
    final res = await c.acceptInvite(code);
    if (!context.mounted) return;
    showGlassToast(context, inviteResultMessage(res));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final invite = c.invite;
    return Glass(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invite a friend',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Send your link, or a code they can enter here. Using it sends '
            'you a friend request to accept.',
            style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
          ),
          if (invite != null) ...[
            const SizedBox(height: 14),
            SelectableText(
              inviteLink(invite.code),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: t.accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Code ${invite.code}',
              style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
            ),
          ],
          const SizedBox(height: 16),
          if (invite == null)
            Builder(
              builder: (context) => GlassButton(
                label: 'Share invite link',
                busy: c.inviting,
                onPressed: () => _create(context),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) => GlassButton(
                      label: 'Share',
                      onPressed: () => _share(context, inviteLink(invite.code)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassButton(
                    label: 'Copy link',
                    secondary: true,
                    onPressed: () => _copy(context, inviteLink(invite.code)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => _enterCode(context),
              style: TextButton.styleFrom(foregroundColor: t.accent),
              child: const Text('Have a code? Enter it'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pops the cleaned code (see [inviteCodeFrom]), or null when dismissed.
class _InviteCodeSheet extends StatefulWidget {
  const _InviteCodeSheet();

  @override
  State<_InviteCodeSheet> createState() => _InviteCodeSheetState();
}

class _InviteCodeSheetState extends State<_InviteCodeSheet> {
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
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter an invite',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Paste the link or type the code a friend sent you.',
              style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
            ),
            const SizedBox(height: 14),
            Glass(
              radius: BorderRadius.circular(14),
              padding: const EdgeInsets.only(left: 14),
              child: TextField(
                controller: _text,
                autofocus: true,
                autocorrect: false,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Code or invite link',
                  hintStyle: TextStyle(color: t.muted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  suffixIcon: TextButton(
                    onPressed: _paste,
                    style: TextButton.styleFrom(foregroundColor: t.accent),
                    child: const Text('Paste'),
                  ),
                ),
              ),
            ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            GlassButton(label: 'Add friend', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

/// A person row: their avatar, name, one line and their actions.
class _Person extends StatelessWidget {
  final String username;
  final String? subtitle;
  final bool busy;
  final List<Widget> actions;
  const _Person({
    required this.username,
    this.subtitle,
    required this.busy,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return GlassRow(
      leading: FriendAvatar(username),
      title: username.isEmpty ? 'Someone' : username,
      subtitle: subtitle,
      trailing: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : actions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
    );
  }
}

/// A round initial in a colour picked from the name, so each friend keeps
/// the same colour everywhere.
class FriendAvatar extends StatelessWidget {
  final String username;
  final double size;
  const FriendAvatar(this.username, {super.key, this.size = 38});

  static const _colors = [
    Color(0xFF0EA5E9),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEC4899),
    Color(0xFF6366F1),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    final name = username.isEmpty ? '?' : username;
    final color =
        _colors[name.codeUnits.fold(0, (a, b) => a + b) % _colors.length];
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: Text(
            name[0].toUpperCase(),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.42,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoFriends extends StatelessWidget {
  const _NoFriends();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    return Glass(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: t.track, shape: BoxShape.circle),
            child: const SizedBox.square(
              dimension: 52,
              child: Icon(Icons.group_outlined, size: 26),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No friends yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Friends you pick hear when you miss a habit. Find them by '
            'username, or send an invite.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
          ),
        ],
      ),
    );
  }
}
