import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation.dart';
import '../../core/problem.dart';
import '../../data/inbox_repository.dart';
import '../../session/session_controller.dart';
import '../../theme/glass.dart';
import 'inbox_view.dart';

/// The Today header's inbox button with an unread badge. No push yet, so the
/// count is re-read when Today loads, when the app resumes and when the user
/// comes back to Today from another screen.
class InboxBell extends StatefulWidget {
  const InboxBell({super.key});

  @override
  State<InboxBell> createState() => _InboxBellState();
}

class _InboxBellState extends State<InboxBell>
    with WidgetsBindingObserver, RouteAware {
  late final InboxRepository _inbox;
  late final SessionController _session;
  int _unread = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = context.read<SessionController>();
    _inbox = InboxRepository(_session.auth.makeApiClient());
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void didPopNext() => _refresh();

  Future<void> _refresh() async {
    final uid = _session.userId;
    if (uid == null || _loading) return;
    _loading = true;
    final res = await _inbox.unreadCount(uid);
    _loading = false;
    if (!mounted) return;
    // Best-effort badge: on failure keep the last count; the inbox screen
    // itself reports errors when opened.
    if (res case Ok(:final value)) setState(() => _unread = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _unread > 99 ? '99+' : '$_unread';
    return Pressable(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const InboxView())),
      child: Semantics(
        button: true,
        label: _unread > 0 ? 'Inbox, $_unread unread' : 'Inbox',
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Glass(
              blur: true,
              radius: BorderRadius.all(Radius.circular(18)),
              child: SizedBox.square(
                dimension: 36,
                child: Icon(Icons.notifications_none_rounded, size: 20),
              ),
            ),
            if (_unread > 0)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: theme.colorScheme.onError,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
