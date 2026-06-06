import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../generated/zinc/models/habit_overview_habit_res.dart';
import '../../generated/zinc/models/week_status_res.dart';
import '../../session/session_controller.dart';
import '../charity/charity_picker.dart';
import '../habit/habit_editor_view.dart';
import '../profile/profile_view.dart';
import '../vacation/vacation_list_view.dart';
import 'buffers_controller.dart';
import 'dashboard_controller.dart';

/// Opens the standalone charity browser (M4) in non-selection mode: tapping a
/// charity opens its detail screen rather than returning a selection.
void _openCharityBrowse(BuildContext context) {
  final session = context.read<SessionController>();
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CharityBrowse(
        repository: session.charities,
        causeRepository: session.causes,
        selectionMode: false,
      ),
    ),
  );
}

/// Opens the habit editor (create when [habitId] is null, else edit) and reloads
/// the dashboard if it reports a change.
Future<void> _openEditor(
  BuildContext context,
  DashboardController c, {
  String? habitId,
  bool enabled = true,
}) async {
  final changed = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) =>
          HabitEditorView(habitId: habitId, initialEnabled: enabled),
    ),
  );
  if (changed == true) c.load();
}

/// True when a debt string represents a non-zero amount (zinc sends debt as a
/// decimal string, e.g. "0.00" or "12.50").
bool _hasDebt(String? debt) {
  if (debt == null || debt.isEmpty) return false;
  final value = double.tryParse(debt);
  return value == null ? debt != '0' : value > 0;
}

/// M2 — the daily loop. Today's habits with complete/skip, streaks, debt and the
/// skip budget, from `GET /Habit/{userId}/overview`.
class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (ctx) =>
              DashboardController(ctx.read<SessionController>())..load(),
        ),
        // Live freeze balance for the buffers strip — a light, separate fetch so
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
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning to the foreground: refetch so completions made on the home-screen
    // widget (which the app isn't notified of) get tallied here too.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<DashboardController>().load();
      context.read<BuffersController>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DashboardController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volunteer_activism),
            tooltip: 'Browse charities',
            onPressed: () => _openCharityBrowse(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: c.phase == DashboardPhase.loading ? null : c.load,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileView())),
          ),
        ],
      ),
      floatingActionButton: c.phase == DashboardPhase.ready
          ? FloatingActionButton(
              onPressed: () => _openEditor(context, c),
              child: const Icon(Icons.add),
            )
          : null,
      body: switch (c.phase) {
        DashboardPhase.loading => const AppLoader(),
        DashboardPhase.error => _ErrorRetry(
          message: c.error?.detail ?? c.error?.title ?? 'Could not load habits',
          onRetry: c.load,
        ),
        DashboardPhase.ready => _Content(c: c),
      },
    );
  }
}

class _Content extends StatelessWidget {
  final DashboardController c;
  const _Content({required this.c});

  @override
  Widget build(BuildContext context) {
    final habits = c.habits;
    final buffers = context.watch<BuffersController>();
    return RefreshIndicator(
      // Pull-to-refresh reloads both the overview and the live freeze balance.
      onRefresh: () => Future.wait([c.load(), buffers.load()]),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (c.actionError != null)
            _ActionErrorBanner(
              message: c.actionError!.detail ?? c.actionError!.title,
              onDismiss: c.clearActionError,
            ),
          _BuffersCard(dashboard: c, buffers: buffers),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            const _EmptyState()
          else
            ...habits.map(
              (h) => _HabitCard(
                key: ValueKey(h.id ?? h.name),
                habit: h,
                controller: c,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact buffers strip: the live **freeze balance** (`GET /Protection`), the
/// monthly **skip budget** (from the habit overview), the current debt, and an
/// entry point to manage vacations. Freeze is a real server value here — never a
/// hardcoded 5/5.
class _BuffersCard extends StatelessWidget {
  final DashboardController dashboard;
  final BuffersController buffers;
  const _BuffersCard({required this.dashboard, required this.buffers});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skipsLeft = dashboard.skipsLeft;
    final totalSkip = dashboard.totalSkip;
    final balance = buffers.balance;
    final owed = _hasDebt(dashboard.totalDebt);

    final freezeLabel = balance == null
        ? (buffers.loading ? '…' : '—')
        : '${balance.balance}/${balance.cap}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Safety nets',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'What are these?',
                  onPressed: () => _showInfo(context),
                ),
              ],
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _stat(
                      theme,
                      Icons.ac_unit,
                      'Freezes',
                      freezeLabel,
                      'auto-saves a miss',
                      color: AppColors.freeze,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _stat(
                      theme,
                      Icons.fast_forward,
                      'Skips',
                      '$skipsLeft/$totalSkip',
                      'you choose, monthly',
                    ),
                  ),
                ],
              ),
            ),
            if (owed) ...[
              const SizedBox(height: 8),
              _stat(
                theme,
                Icons.account_balance_wallet,
                'Owed',
                '${dashboard.totalDebt}',
                'to charity',
                color: theme.colorScheme.error,
              ),
            ],
            const Divider(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(
                Icons.beach_access,
                color: AppColors.vacation,
              ),
              title: const Text('Vacations'),
              subtitle: const Text('Pause habits for a date range'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VacationListView()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your safety nets',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _infoRow(
                context,
                Icons.ac_unit,
                AppColors.freeze,
                'Freezes',
                'Automatic. If you miss a scheduled day, a freeze is spent for '
                    'you — your streak survives and you’re not charged. You earn '
                    'them over time, and the cap grows as your streak grows.',
              ),
              _infoRow(
                context,
                Icons.fast_forward,
                null,
                'Skips',
                'You choose these. Tap Skip when you know you won’t do a habit '
                    'today — it won’t break your streak or charge you. Limited to '
                    'a monthly allowance.',
              ),
              _infoRow(
                context,
                Icons.beach_access,
                AppColors.vacation,
                'Vacation',
                'Pause all habits for a date range, for longer breaks. No misses '
                    'and no charges while a vacation is active.',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color ?? theme.colorScheme.onSurfaceVariant,
            size: 22,
          ),
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
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A distinct bordered pill so each safety net reads as its own thing (not a
  /// flow from one into the next).
  Widget _stat(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    String hint, {
    Color? color,
  }) {
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      value,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  hint,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final HabitOverviewHabitRes habit;
  final DashboardController controller;
  const _HabitCard({super.key, required this.habit, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = habit.status;
    final busy = controller.isBusy(habit);
    final stake = habit.stake;
    final stakeLabel =
        '${stake.currency ?? ''} ${stake.amount.toStringAsFixed(2)}'.trim();

    // days[] is bool[7] indexed Sunday=0 (zinc HabitOverviewMapper.ToDays). Map
    // Dart's weekday (Mon=1..Sun=7) into it: Sun→0, Mon→1, … Sat→6.
    final todayIndex = DateTime.now().weekday % 7;
    final days = habit.days ?? const <bool>[];
    final scheduledToday = todayIndex < days.length && days[todayIndex];
    final restDay = !scheduledToday;
    final paused = !habit.enabled;
    final done = status.isCompleteToday;
    final skipped = _todayStatus(status.week, todayIndex) == 'skip';
    final dim = paused || restDay || done || skipped;

    return Opacity(
      opacity: dim ? 0.6 : 1,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: habit.id == null
              ? null
              : () => _openEditor(
                  context,
                  controller,
                  habitId: habit.id,
                  enabled: habit.enabled,
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.gradientFor(habit.id),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            habit.name ?? 'Habit',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (status.currentStreak > 0) ...[
                          const Icon(
                            Icons.local_fire_department,
                            size: 18,
                            color: AppColors.streak,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${status.currentStreak}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (status.maxStreak > 0) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.emoji_events,
                            size: 17,
                            color: AppColors.best,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${status.maxStreak}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$stakeLabel → ${habit.charity.name ?? 'charity'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _scheduleSummary(habit.days),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _todayRow(
                      context,
                      busy: busy,
                      paused: paused,
                      restDay: restDay,
                      done: done,
                      skipped: skipped,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Today-centric state (mirrors argon): only show Complete/Skip when today is a
  /// scheduled, actionable day; otherwise a status line (paused / done / skipped /
  /// rest day).
  Widget _todayRow(
    BuildContext context, {
    required bool busy,
    required bool paused,
    required bool restDay,
    required bool done,
    required bool skipped,
  }) {
    final theme = Theme.of(context);
    if (busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (paused) return _statusLine(theme, Icons.pause_circle_outline, 'Paused');
    if (done) {
      return _statusLine(
        theme,
        Icons.check_circle,
        'Completed today',
        color: Colors.green.shade700,
      );
    }
    if (skipped) return _statusLine(theme, Icons.fast_forward, 'Skipped today');
    if (restDay) return _statusLine(theme, Icons.bedtime_outlined, 'Rest day');

    final canSkip = controller.skipsLeft > 0;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Complete'),
            onPressed: () => controller.complete(habit),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          // The theme's default minimumSize is Size.fromHeight(50) == infinite
          // min width, which is fine for a full-width button but crashes layout
          // ("BoxConstraints forces an infinite width") for a non-flex child in
          // a Row. Pin a bounded min width so Skip sizes to its content.
          style: OutlinedButton.styleFrom(minimumSize: const Size(88, 50)),
          onPressed: canSkip ? () => controller.skip(habit) : null,
          child: const Text('Skip'),
        ),
      ],
    );
  }

  Widget _statusLine(
    ThemeData theme,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 20, color: c),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelLarge?.copyWith(color: c)),
      ],
    );
  }

  static String? _todayStatus(WeekStatusRes w, int idx) => [
    w.sunday,
    w.monday,
    w.tuesday,
    w.wednesday,
    w.thursday,
    w.friday,
    w.saturday,
  ][idx];
}

/// Human-readable schedule from days[] (Sunday=0), mirroring argon's
/// scheduleSummary.
String _scheduleSummary(List<bool>? days) {
  final d = days ?? const <bool>[];
  final active = d.where((x) => x).length;
  if (active == 0) return 'No schedule';
  if (active == 7) return 'Every day';
  if (active == 5 && d.length >= 6 && d[1] && d[2] && d[3] && d[4] && d[5]) {
    return 'Weekdays';
  }
  if (active == 2 && d.length >= 7 && d[0] && d[6]) return 'Weekends';
  const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  return [
    for (var i = 0; i < d.length && i < 7; i++)
      if (d[i]) names[i],
  ].join(', ');
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Icon(
            Icons.task_alt,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('No habits yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Create one to start staking.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ActionErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.error_outline,
          color: theme.colorScheme.onErrorContainer,
        ),
        title: Text(
          message,
          style: TextStyle(color: theme.colorScheme.onErrorContainer),
        ),
        trailing: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onErrorContainer),
          onPressed: onDismiss,
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
