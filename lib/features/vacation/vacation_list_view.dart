import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:provider/provider.dart';

import '../../core/date_format.dart';
import '../../session/session_controller.dart';
import 'vacation_controller.dart';
import 'vacation_create_view.dart';

/// M7 — the vacation windows screen. Lists scheduled/active/past vacations with
/// status, offers Delete on any window and 'End today' only for active ones, and
/// an entry point to create a new window.
class VacationListView extends StatelessWidget {
  const VacationListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          VacationController(ctx.read<SessionController>())..load(),
      child: const _VacationScaffold(),
    );
  }
}

class _VacationScaffold extends StatelessWidget {
  const _VacationScaffold();

  Future<void> _openCreate(BuildContext context, VacationController c) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: c,
          child: const VacationCreateView(),
        ),
      ),
    );
    // The create view refreshes the controller on success; nothing else to do.
    if (created == true && context.mounted) {
      // no-op: list already refreshed by the controller.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<VacationController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Vacations')),
      floatingActionButton: c.phase == VacationPhase.ready
          ? FloatingActionButton.extended(
              onPressed: () => _openCreate(context, c),
              icon: const Icon(Icons.add),
              label: const Text('Schedule'),
            )
          : null,
      body: switch (c.phase) {
        VacationPhase.loading => const AppLoader(),
        VacationPhase.error => _ErrorRetry(
          message:
              c.error?.detail ?? c.error?.title ?? 'Could not load vacations',
          onRetry: c.load,
        ),
        VacationPhase.ready => _List(c: c),
      },
    );
  }
}

class _List extends StatelessWidget {
  final VacationController c;
  const _List({required this.c});

  @override
  Widget build(BuildContext context) {
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
          if (c.items.isEmpty)
            const _EmptyState()
          else
            ...c.items.map((item) => _VacationCard(item: item, controller: c)),
        ],
      ),
    );
  }
}

class _VacationCard extends StatelessWidget {
  final VacationItem item;
  final VacationController controller;
  const _VacationCard({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = item.res;
    final busy = controller.isBusy(item.id);
    final start = tryParseStandardDate(v.startDate);
    final end = tryParseStandardDate(v.endDate);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _StatusChip(status: item.status),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dateBlock(theme, 'FROM', start)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(child: _dateBlock(theme, 'TO', end)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.public,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _meta(v.timezone, start, end),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (item.isActive)
                    TextButton.icon(
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('End today'),
                      onPressed: () => _confirmEndToday(context),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => _confirmDelete(context),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete vacation?'),
        content: const Text(
          'This removes the scheduled window. A vacation that has already '
          'started cannot be deleted — use "End today" instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.remove(item.id);
  }

  Future<void> _confirmEndToday(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End vacation today?'),
        content: const Text(
          'This ends the active vacation as of today. Your habits resume '
          'tomorrow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End today'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.endToday(item.id);
  }

  Widget _dateBlock(ThemeData theme, String label, DateTime? d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _pretty(d),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// "Asia/Singapore · 10 days" (duration inclusive of both ends).
  String _meta(String? tz, DateTime? start, DateTime? end) {
    final parts = <String>[if (tz != null && tz.isNotEmpty) tz];
    if (start != null && end != null) {
      final days = end.difference(start).inDays + 1;
      parts.add('$days day${days == 1 ? '' : 's'}');
    }
    return parts.isEmpty ? 'Unknown' : parts.join('  ·  ');
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _pretty(DateTime? d) =>
      d == null ? '—' : '${d.day} ${_months[d.month - 1]} ${d.year}';
}

class _StatusChip extends StatelessWidget {
  final VacationStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, icon) = switch (status) {
      VacationStatus.active => (
        'Active',
        theme.colorScheme.primary,
        Icons.beach_access,
      ),
      VacationStatus.upcoming => (
        'Upcoming',
        theme.colorScheme.tertiary,
        Icons.schedule,
      ),
      VacationStatus.ended => (
        'Ended',
        theme.colorScheme.onSurfaceVariant,
        Icons.history,
      ),
    };
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color)),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
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
          Icon(
            Icons.beach_access,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('No vacations scheduled', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Schedule a window to pause your habits while you’re away.',
            textAlign: TextAlign.center,
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
