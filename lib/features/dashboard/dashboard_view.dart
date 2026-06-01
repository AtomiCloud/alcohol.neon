import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../../generated/zinc/models/habit_overview_habit_res.dart';
import '../../generated/zinc/models/week_status_res.dart';
import '../../session/session_controller.dart';
import 'dashboard_controller.dart';

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
    final done = status.isCompleteToday;
    final busy = controller.isBusy(habit);
    final stake = habit.stake;
    final stakeLabel =
        '${stake.currency ?? ''} ${stake.amount.toStringAsFixed(2)}'.trim();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
            const SizedBox(height: 10),
            _WeekStrip(week: status.week),
            const SizedBox(height: 10),
            _actions(context, done: done, busy: busy),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, {required bool done, required bool busy}) {
    final theme = Theme.of(context);
    if (busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (done) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 6),
          Text('Done today',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: Colors.green.shade700)),
        ],
      );
    }
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
}

/// Sun→Sat status dots from `WeekStatusRes` (named day fields — avoids guessing
/// the `days[]` index base).
class _WeekStrip extends StatelessWidget {
  final WeekStatusRes week;
  const _WeekStrip({required this.week});

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String?)>[
      ('S', week.sunday),
      ('M', week.monday),
      ('T', week.tuesday),
      ('W', week.wednesday),
      ('T', week.thursday),
      ('F', week.friday),
      ('S', week.saturday),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (label, status) in entries) _dot(context, label, status),
      ],
    );
  }

  Widget _dot(BuildContext context, String label, String? status) {
    final theme = Theme.of(context);
    final (color, icon) = _style(status, theme);
    return Column(
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        CircleAvatar(
          radius: 11,
          backgroundColor: color,
          child: icon == null
              ? null
              : Icon(icon, size: 13, color: theme.colorScheme.surface),
        ),
      ],
    );
  }

  /// Maps an execution status to a dot color/icon. Statuses:
  /// succeeded | failed | skip | frozen | vacation | not_applicable.
  (Color, IconData?) _style(String? status, ThemeData theme) {
    switch (status) {
      case 'succeeded':
        return (Colors.green.shade500, Icons.check);
      case 'failed':
        return (theme.colorScheme.error, Icons.close);
      case 'skip':
        return (Colors.blueGrey.shade300, Icons.fast_forward);
      case 'frozen':
      case 'vacation':
        return (Colors.lightBlue.shade200, Icons.ac_unit);
      default:
        return (theme.colorScheme.surfaceContainerHighest, null);
    }
  }
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
