import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../../generated/zinc/models/habit_overview_habit_res.dart';
import '../../generated/zinc/models/week_status_res.dart';
import '../../session/session_controller.dart';
import '../habit/habit_editor_view.dart';
import 'dashboard_controller.dart';

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
    return ChangeNotifierProvider(
      create: (ctx) => DashboardController(ctx.read<SessionController>())..load(),
      child: const _DashboardScaffold(),
    );
  }
}

class _DashboardScaffold extends StatelessWidget {
  const _DashboardScaffold();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DashboardController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: c.phase == DashboardPhase.loading ? null : c.load,
          ),
          TextButton(
            onPressed: () => context.read<AuthService>().signOut(),
            child: const Text('Sign out'),
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
        DashboardPhase.loading =>
          const Center(child: CircularProgressIndicator()),
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
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (c.actionError != null)
            _ActionErrorBanner(
              message: c.actionError!.detail ?? c.actionError!.title,
              onDismiss: c.clearActionError,
            ),
          _SummaryBar(skipsLeft: c.skipsLeft, totalDebt: c.totalDebt),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            const _EmptyState()
          else
            ...habits.map((h) => _HabitCard(habit: h, controller: c)),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int skipsLeft;
  final String? totalDebt;
  const _SummaryBar({required this.skipsLeft, required this.totalDebt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final owed = _hasDebt(totalDebt);
    return Row(
      children: [
        _pill(theme, Icons.ac_unit, '$skipsLeft skip${skipsLeft == 1 ? '' : 's'} left'),
        const SizedBox(width: 8),
        if (owed)
          _pill(theme, Icons.account_balance_wallet, 'Owed $totalDebt',
              color: theme.colorScheme.error),
      ],
    );
  }

  Widget _pill(ThemeData theme, IconData icon, String label, {Color? color}) {
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Chip(
      avatar: Icon(icon, size: 18, color: c),
      label: Text(label, style: TextStyle(color: c)),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _HabitCard extends StatelessWidget {
  final HabitOverviewHabitRes habit;
  final DashboardController controller;
  const _HabitCard({required this.habit, required this.controller});

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
        child: InkWell(
          onTap: habit.id == null
              ? null
              : () => _openEditor(context, controller,
                  habitId: habit.id, enabled: habit.enabled),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(habit.name ?? 'Habit',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    if (status.currentStreak > 0)
                      Text('🔥 ${status.currentStreak}',
                          style: theme.textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$stakeLabel → ${habit.charity.name ?? 'charity'}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  _scheduleSummary(habit.days),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                _todayRow(context,
                    busy: busy,
                    paused: paused,
                    restDay: restDay,
                    done: done,
                    skipped: skipped),
              ],
            ),
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
            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (paused) return _statusLine(theme, Icons.pause_circle_outline, 'Paused');
    if (done) {
      return _statusLine(theme, Icons.check_circle, 'Completed today',
          color: Colors.green.shade700);
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
          onPressed: canSkip ? () => controller.skip(habit) : null,
          child: const Text('Skip'),
        ),
      ],
    );
  }

  Widget _statusLine(ThemeData theme, IconData icon, String label,
      {Color? color}) {
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
          Icon(Icons.task_alt,
              size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('No habits yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Create one to start staking.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
        leading: Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
        title: Text(message,
            style: TextStyle(color: theme.colorScheme.onErrorContainer)),
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
