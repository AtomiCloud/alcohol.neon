import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoSliverRefreshControl;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/launch_timeline.dart';

import '../../core/navigation.dart';
import '../../generated/zinc/models/habit_overview_habit_res.dart';
import '../../session/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/app_loader.dart';
import '../habit/habit_editor_view.dart';
import '../inbox/inbox_bell.dart';
import '../profile/profile_view.dart';
import 'buffers_controller.dart';
import 'dashboard_controller.dart';
import 'today_layout.dart';
import 'today_plan.dart';

/// Opens the habit editor (create when [habitId] is null, else edit) and reloads
/// the dashboard if it reports a change.
Future<void> _openEditor(
  BuildContext context,
  DashboardController c, {
  String? habitId,
  bool enabled = true,
}) async {
  // New habit is a task to finish or cancel, so it opens as a modal; Edit
  // goes deeper into one habit, so it's pushed.
  final changed = habitId == null
      ? await showGlassModal<bool>(context, (_) => const HabitEditorView())
      : await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                HabitEditorView(habitId: habitId, initialEnabled: enabled),
          ),
        );
  if (changed == true) c.load();
}

void _openHabit(BuildContext context, DashboardController c, TodayItem item) {
  final id = item.habit.id;
  if (id == null) return;
  _openEditor(context, c, habitId: id, enabled: item.habit.enabled);
}

/// True when a debt string represents a non-zero amount (zinc sends debt as a
/// decimal string, e.g. "0.00" or "12.50").
bool _hasDebt(String? debt) {
  if (debt == null || debt.isEmpty) return false;
  final value = double.tryParse(debt);
  return value == null ? debt != '0' : value > 0;
}

/// "1 h 55 m left", counted down from the item's deadline.
String _timeLeft(DateTime? deadline, DateTime now) {
  if (deadline == null) return '';
  final minutes = deadline.difference(now).inMinutes;
  if (minutes <= 0) return 'Ending now';
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m m left';
  return m == 0 ? '$h h left' : '$h h $m m left';
}

String _statusLabel(TodayState s) => switch (s) {
  TodayState.done => 'Completed today',
  TodayState.skipped => 'Skipped today',
  TodayState.frozen => 'Covered by a freeze today',
  TodayState.vacation => 'On vacation',
  TodayState.settled => 'Today is already settled',
  TodayState.rest => 'Rest day',
  TodayState.paused => 'Paused',
  TodayState.unknown => "Today's status unavailable",
  TodayState.todo => '',
};

String _dateCaption(DateTime d) {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}

Future<void> _complete(DashboardController c, HabitOverviewHabitRes h) {
  HapticFeedback.mediumImpact();
  return c.complete(h);
}

Future<void> _skip(DashboardController c, HabitOverviewHabitRes h) {
  HapticFeedback.selectionClick();
  return c.skip(h);
}

/// The daily loop: today's habits with complete/skip, from
/// `GET /Habit/{userId}/overview`. Leads with the next habit to do ("Next up")
/// or with the day's progress ("Progress list"), as chosen in Profile.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) =>
              // Quiet: a saved Today stays on screen while the fresh one loads.
              DashboardController(ctx.read<SessionController>())
                ..load(quiet: true),
        ),
        // Live freeze balance for the safety nets — a light, separate fetch so
        // the daily-loop controller stays clean.
        ChangeNotifierProvider(
          create: (ctx) =>
              BuffersController(ctx.read<SessionController>())..load(),
        ),
      ],
      child: const _DashboardScaffold(),
    );
  }
}

class _DashboardScaffold extends StatefulWidget {
  const _DashboardScaffold();

  @override
  State<_DashboardScaffold> createState() => _DashboardScaffoldState();
}

class _DashboardScaffoldState extends State<_DashboardScaffold>
    with WidgetsBindingObserver, RouteAware {
  late final SessionController _session;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A timezone sync can settle days that already ended in the new timezone;
    // tell the user once. Bootstrap syncs before this screen exists, so also
    // check after the first frame.
    _session = context.read<SessionController>()
      ..addListener(_showTimezoneNotice)
      ..addListener(_reloadOnTimezoneChange);
    _timezone = _session.config?.timezone;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTimezoneNotice());
  }

  String? _timezone;

  /// Today may come from the saved overview before bootstrap has the fresh
  /// configuration; if that moved the timezone, Today's checks moved too.
  void _reloadOnTimezoneChange() {
    final tz = _session.config?.timezone;
    if (tz == _timezone) return;
    final had = _timezone != null;
    _timezone = tz;
    if (had && tz != null && mounted) {
      context.read<DashboardController>().load(quiet: true);
    }
  }

  void _showTimezoneNotice() {
    if (!mounted) return;
    final notice = _session.takeTimezoneNotice();
    if (notice == null) return;
    showGlassToast(context, notice, duration: const Duration(seconds: 8));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    // Includes a warm NFC link: no app-resume event is required on return.
    if (!mounted) return;
    context.read<DashboardController>().load();
    context.read<BuffersController>().load();
  }

  @override
  void dispose() {
    _session
      ..removeListener(_showTimezoneNotice)
      ..removeListener(_reloadOnTimezoneChange);
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the foreground: refetch so completions made on the home-screen
    // widget (which the app isn't notified of) get tallied here too.
    if (state == AppLifecycleState.resumed && mounted) {
      _onResumed();
    }
  }

  /// Follow the phone first (the user may have travelled while away), so the
  /// reload — which also re-plans reminders, dropping today's for habits
  /// completed meanwhile (e.g. on the home-screen widget) — sees the new
  /// timezone.
  Future<void> _onResumed() async {
    final dashboard = context.read<DashboardController>();
    context.read<BuffersController>().load();
    await context.read<SessionController>().syncDeviceTimezone();
    if (mounted) dashboard.load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DashboardController>();
    return AmbientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: c.phase == DashboardPhase.ready
            ? _AddButton(onTap: () => _openEditor(context, c))
            : null,
        body: switch (c.phase) {
          DashboardPhase.loading => const AppLoader(),
          DashboardPhase.error => _ErrorRetry(
            message: c.error?.displayMessage ?? 'Could not load habits',
            onRetry: c.load,
          ),
          DashboardPhase.ready => ValueListenableBuilder<TodayLayout>(
            valueListenable: TodayLayoutSetting.instance,
            builder: (_, layout, _) => _Today(c: c, layout: layout),
          ),
        },
      ),
    );
  }
}

/// The scrolling Today screen: a large title that collapses into a frosted
/// bar, then the chosen layout. Rebuilds every 30 s so countdowns stay live.
class _Today extends StatefulWidget {
  final DashboardController c;
  final TodayLayout layout;
  const _Today({required this.c, required this.layout});

  @override
  State<_Today> createState() => _TodayState();
}

class _TodayState extends State<_Today> {
  late final Timer _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => LaunchTimeline.todayShown(widget.c.fromCache ? 'cache' : 'server'),
    );
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final buffers = context.watch<BuffersController>();
    final plan = c.plan;
    final now = DateTime.now();
    final nextUp = widget.layout == TodayLayout.nextUp;

    final sections = <Widget>[
      if (c.refreshError != null)
        GlassBanner(
          icon: Icons.sync_problem,
          title: 'Could not refresh the dashboard',
          body:
              'Saved actions are kept. Totals may be out of date. '
              'Retry refresh — do not submit the action again.',
          action: GlassTextButton(label: 'Retry', onPressed: c.load),
        ),
      if (c.actionError != null)
        GlassBanner(
          icon: Icons.error_outline,
          title: c.actionError!.displayMessage,
          error: true,
          action: IconButton(
            icon: const Icon(Icons.close),
            onPressed: c.clearActionError,
          ),
        ),
      if (c.habits.isEmpty)
        _EmptyState(onCreate: () => _openEditor(context, c))
      else if (nextUp)
        ..._nextUpSections(context, c, buffers, plan, now)
      else
        ..._progressSections(context, c, buffers, plan, now),
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _LargeTitle(
            top: MediaQuery.paddingOf(context).top,
            caption: _dateCaption(now),
            ring: nextUp && plan.scheduled > 0
                ? ProgressRing(
                    value: plan.done.length / plan.scheduled,
                    size: 34,
                    stroke: 3.5,
                    child: Text(
                      '${plan.done.length}/${plan.scheduled}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
            onProfile: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileView())),
          ),
        ),
        // Pull-to-refresh reloads both the overview and the freeze balance.
        CupertinoSliverRefreshControl(
          onRefresh: () => Future.wait([c.load(), buffers.load()]),
        ),
        // One scroll view for every section, so dragging a row to an edge
        // scrolls Today.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          sliver: SliverMainAxisGroup(
            slivers: [
              for (var i = 0; i < sections.length; i++)
                sections[i] is _Section
                    ? Appear(index: i, sliver: true, child: sections[i])
                    : SliverToBoxAdapter(
                        child: Appear(index: i, child: sections[i]),
                      ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _nextUpSections(
    BuildContext context,
    DashboardController c,
    BuffersController buffers,
    TodayPlan plan,
    DateTime now,
  ) {
    final next = plan.next;
    return [
      AnimatedSwitcher(
        duration: GlassMotion.of(context, GlassMotion.slow),
        switchInCurve: GlassMotion.curve,
        switchOutCurve: GlassMotion.curve,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(a),
            child: child,
          ),
        ),
        child: next == null
            ? _AllClear(key: const ValueKey('clear'), plan: plan)
            : _NextUpCard(
                key: ValueKey(next.habit.id ?? next.habit.name),
                item: next,
                c: c,
                now: now,
              ),
      ),
      if (plan.todo.length > 1)
        _Section(
          title: 'Later today',
          items: [
            for (final i in plan.todo)
              if (i != next) i,
          ],
          c: c,
          now: now,
        ),
      if (plan.done.isNotEmpty)
        _Section(title: 'Done', items: plan.done, c: c, now: now),
      if (plan.later.isNotEmpty)
        _Section(title: 'Not today', items: plan.later, c: c, now: now),
      _SafetyNets(c: c, buffers: buffers),
    ];
  }

  List<Widget> _progressSections(
    BuildContext context,
    DashboardController c,
    BuffersController buffers,
    TodayPlan plan,
    DateTime now,
  ) {
    return [
      _ProgressCard(c: c, buffers: buffers, plan: plan, now: now),
      if (plan.scheduled > 0)
        _Section(
          title: 'Today',
          items: [...plan.todo, ...plan.done],
          // Done stays below open: rows move only within their own group.
          split: plan.todo.length,
          c: c,
          now: now,
        ),
      if (plan.later.isNotEmpty)
        _Section(title: 'Not today', items: plan.later, c: c, now: now),
    ];
  }
}

/// iOS-style large title: the date and "Today" scroll away and a small title
/// fades in on a frosted bar. Only that bar uses a real backdrop blur.
class _LargeTitle extends SliverPersistentHeaderDelegate {
  final double top;
  final String caption;
  final Widget? ring;
  final VoidCallback onProfile;

  const _LargeTitle({
    required this.top,
    required this.caption,
    required this.ring,
    required this.onProfile,
  });

  static const _bar = 52.0;

  @override
  double get minExtent => top + _bar;

  @override
  double get maxExtent => top + _bar + 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final p = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final barOpacity = ((p - 0.5) / 0.5).clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (barOpacity > 0)
          Opacity(
            opacity: barOpacity,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.strongFill,
                    border: Border(
                      bottom: BorderSide(color: t.separator, width: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: top,
          left: 0,
          right: 0,
          height: _bar,
          child: Opacity(
            opacity: barOpacity,
            child: Center(
              child: Text(
                'Today',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: top + 8,
          right: 16,
          child: Row(
            children: [
              if (ring != null) ...[ring!, const SizedBox(width: 10)],
              const InboxBell(),
              const SizedBox(width: 10),
              Pressable(
                onTap: onProfile,
                child: Semantics(
                  button: true,
                  label: 'Profile',
                  child: Glass(
                    blur: true,
                    radius: const BorderRadius.all(Radius.circular(18)),
                    child: const SizedBox.square(
                      dimension: 36,
                      child: Icon(Icons.person_rounded, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 6,
          child: Opacity(
            opacity: (1 - p * 1.8).clamp(0.0, 1.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption,
                  style: theme.textTheme.labelLarge?.copyWith(color: t.muted),
                ),
                Text(
                  'Today',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 34,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_LargeTitle old) => true;
}

/// The habit due soonest, with its countdown, stake and the one action to take.
class _NextUpCard extends StatelessWidget {
  final TodayItem item;
  final DashboardController c;
  final DateTime now;
  const _NextUpCard({
    super.key,
    required this.item,
    required this.c,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final h = item.habit;
    final busy = c.isBusy(h);
    final stake = stakeLine(h);
    final skipsLeft = c.skipsLeft;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Pressable(
        onTap: () => _openHabit(context, c, item),
        scale: 0.985,
        child: Glass(
          radius: const BorderRadius.all(Radius.circular(28)),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Next up',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: t.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _timeLeft(item.deadline, now),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: t.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      h.name ?? 'Habit',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (h.status.currentStreak > 0)
                    _Streak(h.status.currentStreak),
                ],
              ),
              if (stake != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.volunteer_activism_outlined,
                      size: 16,
                      color: t.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stake,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: t.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (proofLabel(h) case final proof?) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.directions_run, size: 16, color: t.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Checks off from $proof, or complete it here',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: t.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              GlassButton(
                label: 'Complete',
                busy: busy,
                onPressed: () => _complete(c, h),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GlassTextButton(
                    label: 'Skip',
                    muted: true,
                    onPressed: busy || skipsLeft <= 0
                        ? null
                        : () => _skip(c, h),
                  ),
                  Text(
                    '$skipsLeft left this month',
                    style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown in place of Next up once nothing is left to do today.
class _AllClear extends StatelessWidget {
  final TodayPlan plan;
  const _AllClear({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final none = plan.scheduled == 0;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Glass(
        radius: const BorderRadius.all(Radius.circular(28)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(
              none ? Icons.bedtime_outlined : Icons.check_circle_rounded,
              size: 44,
              color: none ? t.muted : t.accent,
            ),
            const SizedBox(height: 12),
            Text(
              none ? 'Nothing due today' : 'All done for today',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              none
                  ? 'Enjoy the rest.'
                  : '${plan.done.length} of ${plan.scheduled} settled. See you tomorrow.',
              style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress list's header: today's ring, what's next, and the safety nets.
class _ProgressCard extends StatelessWidget {
  final DashboardController c;
  final BuffersController buffers;
  final TodayPlan plan;
  final DateTime now;
  const _ProgressCard({
    required this.c,
    required this.buffers,
    required this.plan,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final next = plan.next;
    final done = plan.done.length, total = plan.scheduled;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Glass(
        radius: const BorderRadius.all(Radius.circular(28)),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProgressRing(
                  value: total == 0 ? 0 : done / total,
                  size: 68,
                  stroke: 7,
                  child: Text(
                    '$done/$total',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        total == 0
                            ? 'Nothing due today'
                            : next == null
                            ? 'All done for today'
                            : '$done of $total done',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next == null
                            ? 'See you tomorrow.'
                            : 'Next: ${next.habit.name ?? 'Habit'} · '
                                  '${_timeLeft(next.deadline, now)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: t.muted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _NetPills(c: c, buffers: buffers),
          ],
        ),
      ),
    );
  }
}

/// A titled glass group of habit rows, as a sliver of Today's scroll view.
/// Long-press a row and drag it to reorder the group (when zinc keeps an
/// order); a drop saves the new order.
class _Section extends StatefulWidget {
  final String title;
  final List<TodayItem> items;
  final DashboardController c;
  final DateTime now;

  /// Where a second group starts (the Progress list's done rows). Rows move
  /// only within their own group.
  final int? split;
  const _Section({
    required this.title,
    required this.items,
    required this.c,
    required this.now,
    this.split,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  static const _radius = BorderRadius.all(Radius.circular(22));

  // The rows as they were when a drag started: a load landing mid-drag must
  // not move rows under the finger (or end the drag). It applies on drop.
  List<TodayItem>? _frozen;
  List<TodayItem> get _items => _frozen ?? widget.items;

  // For the tick as the lifted row passes another row.
  final _rowKeys = <String, GlobalKey>{};
  List<double> _centers = const [];
  int _dragIndex = 0, _slot = 0;
  double _downY = 0;

  String _id(TodayItem i) => i.habit.id ?? i.habit.name ?? '';

  /// The rows the row at [index] may move among, as [start, end).
  (int, int) _group(int index) {
    final split = widget.split;
    if (split == null) return (0, _items.length);
    return index < split ? (0, split) : (split, _items.length);
  }

  bool _canMove(int index) {
    if (!widget.c.canReorder) return false;
    final (start, end) = _group(index);
    return end - start > 1;
  }

  void _move(int from, int to) {
    final (start, end) = _group(from);
    // A drop past the group's edge lands at the nearest allowed place.
    final target = to.clamp(start, end - 1);
    final ids = [for (final i in _items.sublist(start, end)) _id(i)];
    ids.insert(target - start, ids.removeAt(from - start));
    setState(() => _frozen = null);
    // Only this group's habits trade places; the rest keep theirs.
    if (target != from) widget.c.reorder(ids);
  }

  void _onStart(int index) {
    HapticFeedback.mediumImpact();
    _dragIndex = _slot = index;
    // Rebuilt so the row under a lifted first row drops its divider.
    setState(() => _frozen = widget.items);
    _centers = [
      for (final i in _items)
        switch (_rowKeys[_id(i)]?.currentContext?.findRenderObject()) {
          final RenderBox box when box.hasSize =>
            box.localToGlobal(box.size.center(Offset.zero)).dy,
          _ => double.nan,
        },
    ];
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_frozen == null || _dragIndex >= _centers.length) return;
    final y = _centers[_dragIndex] + e.position.dy - _downY;
    var slot = 0;
    for (var i = 0; i < _centers.length; i++) {
      if (i != _dragIndex && _centers[i] < y) slot++;
    }
    if (slot != _slot) {
      _slot = slot;
      HapticFeedback.selectionClick();
    }
  }

  Widget _row(int index, {bool lifted = false}) {
    final item = _items[index];
    final id = _id(item);
    final first = index == 0, last = index == _items.length - 1;
    // While the first row is lifted, the next one leads the group.
    final divider =
        !first && !(_frozen != null && _dragIndex == 0 && index == 1);
    Widget row = _HabitRow(item: item, c: widget.c, now: widget.now);
    if (lifted) return row;
    final movable = _canMove(index);
    final (start, end) = _group(index);
    row = Semantics(
      customSemanticsActions: movable
          ? {
              if (index > start)
                const CustomSemanticsAction(label: 'Move up'): () =>
                    _move(index, index - 1),
              if (index < end - 1)
                const CustomSemanticsAction(label: 'Move down'): () =>
                    _move(index, index + 1),
            }
          : null,
      child: row,
    );
    return Listener(
      key: ValueKey(id),
      onPointerDown: (e) => _downY = e.position.dy,
      onPointerMove: _onPointerMove,
      // A drag the system cancels drops no row, so nothing calls onReorder.
      onPointerCancel: (_) {
        if (_frozen != null) setState(() => _frozen = null);
      },
      child: ReorderableDelayedDragStartListener(
        index: index,
        enabled: movable,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: first ? _radius.topLeft : Radius.zero,
            bottom: last ? _radius.bottomLeft : Radius.zero,
          ),
          child: Column(
            key: _rowKeys.putIfAbsent(id, GlobalKey.new),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (divider)
                Padding(
                  padding: const EdgeInsets.only(left: 58),
                  child: Divider(
                    height: 0.5,
                    color: GlassTokens.of(context).separator,
                  ),
                ),
              row,
            ],
          ),
        ),
      ),
    );
  }

  /// The lifted row: its own glass raised off the group, with a soft shadow
  /// and a slight scale-up (none under Reduce Motion), and no dividers.
  Widget _lifted(Widget _, int index, Animation<double> a) {
    final still = MediaQuery.of(context).disableAnimations;
    return AnimatedBuilder(
      animation: a,
      builder: (context, child) {
        final t = Curves.easeOut.transform(a.value);
        return Transform.scale(
          scale: still ? 1 : 1 + 0.03 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: _radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18 * t),
                  blurRadius: 24 * t,
                  offset: Offset(0, 8 * t),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(
        type: MaterialType.transparency,
        child: Glass(
          blur: true,
          strong: true,
          child: _row(index, lifted: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final items = _items;
    _rowKeys.removeWhere((id, _) => !items.any((i) => _id(i) == id));
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              widget.title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: t.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        DecoratedSliver(
          decoration: BoxDecoration(
            color: t.fill,
            borderRadius: _radius,
            border: Border.all(color: t.edge, width: 0.5),
          ),
          sliver: SliverReorderableList(
            itemCount: items.length,
            itemBuilder: (_, i) => _row(i),
            proxyDecorator: _lifted,
            onReorderStart: _onStart,
            onReorderEnd: (_) => HapticFeedback.lightImpact(),
            onReorderItem: _move,
          ),
        ),
      ],
    );
  }
}

/// One habit: a check circle (tap to complete when open), its name and today's
/// state. Swipe an open habit left to skip it.
class _HabitRow extends StatelessWidget {
  final TodayItem item;
  final DashboardController c;
  final DateTime now;
  const _HabitRow({required this.item, required this.c, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final h = item.habit;
    final open = item.state == TodayState.todo;
    final busy = c.isBusy(h);
    final quiet =
        item.state == TodayState.rest ||
        item.state == TodayState.paused ||
        item.state == TodayState.unknown;
    final subtitle = [
      open ? _timeLeft(item.deadline, now) : _statusLabel(item.state),
      ?proofLabel(h),
    ].join(' · ');

    final row = Pressable(
      onTap: () => _openHabit(context, c, item),
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            _CheckCircle(
              state: item.state,
              busy: busy,
              onTap: open && !busy ? () => _complete(c, h) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: AnimatedOpacity(
                opacity: open ? 1 : (quiet ? 0.55 : 0.75),
                duration: GlassMotion.of(context, GlassMotion.fast),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h.name ?? 'Habit',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: t.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (h.status.currentStreak > 0) _Streak(h.status.currentStreak),
          ],
        ),
      ),
    );
    if (!open || h.id == null) return row;
    final canSkip = c.skipsLeft > 0 && !busy;
    return Dismissible(
      key: ValueKey('skip-${h.id}'),
      direction: canSkip ? DismissDirection.endToStart : DismissDirection.none,
      // The row stays; the reload moves it into Done once the skip lands.
      confirmDismiss: (_) async {
        unawaited(_skip(c, h));
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: t.track,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fast_forward_rounded, size: 18, color: t.muted),
            const SizedBox(width: 6),
            Text(
              'Skip · ${c.skipsLeft} left',
              style: theme.textTheme.labelLarge?.copyWith(color: t.muted),
            ),
          ],
        ),
      ),
      child: row,
    );
  }
}

class _CheckCircle extends StatelessWidget {
  final TodayState state;
  final bool busy;
  final VoidCallback? onTap;
  const _CheckCircle({required this.state, required this.busy, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final (IconData? icon, Color? fill) = switch (state) {
      TodayState.todo => (null, null),
      TodayState.done => (Icons.check_rounded, t.accent),
      TodayState.skipped => (Icons.fast_forward_rounded, t.muted),
      TodayState.frozen => (Icons.ac_unit_rounded, AppColors.freeze),
      TodayState.vacation => (Icons.beach_access_rounded, AppColors.vacation),
      TodayState.settled => (Icons.close_rounded, AppColors.fail),
      TodayState.rest => (Icons.bedtime_outlined, null),
      TodayState.paused => (Icons.pause_rounded, null),
      TodayState.unknown => (Icons.question_mark_rounded, null),
    };
    final Widget body = busy
        ? SizedBox.square(
            key: const ValueKey('busy'),
            dimension: 26,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: CircularProgressIndicator(strokeWidth: 2, color: t.muted),
            ),
          )
        : Container(
            key: ValueKey(state),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: fill == null
                  ? Border.all(color: t.muted, width: 1.6)
                  : null,
            ),
            child: icon == null
                ? null
                : Icon(
                    icon,
                    size: 16,
                    color: fill == null ? t.muted : Colors.white,
                  ),
          );
    return Semantics(
      button: onTap != null,
      label: onTap != null ? 'Mark done' : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedSwitcher(
            duration: GlassMotion.of(context, GlassMotion.fast),
            transitionBuilder: (child, a) =>
                ScaleTransition(scale: a, child: child),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _Streak extends StatelessWidget {
  final int days;
  const _Streak(this.days);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 16,
            color: AppColors.streak,
          ),
          const SizedBox(width: 2),
          Text(
            '$days',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Next up's quiet footer: freezes, skips and anything owed, tap for details.
class _SafetyNets extends StatelessWidget {
  final DashboardController c;
  final BuffersController buffers;
  const _SafetyNets({required this.c, required this.buffers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            'Safety nets',
            style: theme.textTheme.labelLarge?.copyWith(
              color: t.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _NetPills(c: c, buffers: buffers),
      ],
    );
  }
}

/// Freezes, skips and debt as small glass pills; tapping any explains them.
class _NetPills extends StatelessWidget {
  final DashboardController c;
  final BuffersController buffers;
  const _NetPills({required this.c, required this.buffers});

  @override
  Widget build(BuildContext context) {
    final balance = buffers.balance;
    final freezes = balance == null
        ? (buffers.loading ? '…' : '—')
        : '${balance.balance}/${balance.cap}';
    final owed = _hasDebt(c.totalDebt);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Pill(
          icon: Icons.ac_unit_rounded,
          color: AppColors.freeze,
          label: '$freezes freezes',
        ),
        _Pill(
          icon: Icons.fast_forward_rounded,
          label: '${c.skipsLeft}/${c.totalSkip} skips',
        ),
        if (owed)
          _Pill(
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.fail,
            label: '${c.totalDebt} owed',
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String label;
  const _Pill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Pressable(
      onTap: () => _showSafetyNets(context),
      child: Glass(
        strong: true,
        radius: const BorderRadius.all(Radius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color ?? t.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSafetyNets(BuildContext context) {
  showGlassSheet<void>(
    context,
    (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your safety nets',
              style: Theme.of(
                ctx,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _infoRow(
              ctx,
              Icons.ac_unit_rounded,
              AppColors.freeze,
              'Freezes',
              'Automatic. If you miss a scheduled day, a freeze is spent for '
                  'you — your streak survives and you’re not charged. You earn '
                  'them over time, and the cap grows as your streak grows.',
            ),
            _infoRow(
              ctx,
              Icons.fast_forward_rounded,
              null,
              'Skips',
              'You choose these. Tap Skip, or swipe a habit left, when you '
                  'know you won’t do it today — it won’t break your streak or '
                  'charge you. Limited to a monthly allowance.',
            ),
            _infoRow(
              ctx,
              Icons.beach_access_rounded,
              AppColors.vacation,
              'Vacation',
              'Pause all habits for a date range, for longer breaks. No misses '
                  'and no charges while a vacation is active. Find it in Profile.',
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _infoRow(
  BuildContext context,
  IconData icon,
  Color? color,
  String title,
  String body,
) {
  final theme = Theme.of(context);
  final t = GlassTokens.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color ?? t.muted, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// The frosted "+" that creates a habit.
class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      scale: 0.92,
      child: Semantics(
        button: true,
        label: 'New habit',
        child: Glass(
          blur: true,
          strong: true,
          radius: const BorderRadius.all(Radius.circular(28)),
          child: const SizedBox.square(
            dimension: 56,
            child: Icon(Icons.add_rounded, size: 28),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final followsPhone = context.watch<SessionController>().followPhoneTimezone;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GlassMessage(
        icon: Icons.task_alt_rounded,
        tint: GlassTokens.of(context).accent,
        title: 'Make your first habit',
        body: followsPhone
            ? 'Choose what to do and on which days. Your timezone '
                  'already follows your phone.'
            : 'Choose what to do and on which days.',
        actions: [GlassButton(label: 'Create a habit', onPressed: onCreate)],
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
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: GlassMessage(
            icon: Icons.cloud_off_rounded,
            tint: Theme.of(context).colorScheme.error,
            title: 'Could not load Today',
            body: message,
            actions: [GlassButton(label: 'Retry', onPressed: onRetry)],
          ),
        ),
      ),
    );
  }
}
