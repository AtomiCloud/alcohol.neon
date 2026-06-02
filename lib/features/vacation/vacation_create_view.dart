import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../theme/app_theme.dart';
import '../onboarding/timezone_picker.dart';
import 'vacation_controller.dart';

/// M7 — schedule a vacation window: start + end date pickers (formatted to zinc's
/// `dd-MM-yyyy` by the controller), with a timezone defaulting to the device's
/// (reusing the onboarding [TimezonePicker]). Pops `true` on success so the list
/// can react. Reads its [VacationController] from the provider supplied by the list.
class VacationCreateView extends StatefulWidget {
  const VacationCreateView({super.key});

  @override
  State<VacationCreateView> createState() => _VacationCreateViewState();
}

class _VacationCreateViewState extends State<VacationCreateView> {
  DateTime? _start;
  DateTime? _end;
  String? _timezone;
  List<String> _timezones = const [];

  bool _loadingTz = true;
  bool _submitting = false;
  Problem? _error;

  @override
  void initState() {
    super.initState();
    _loadTimezones();
  }

  Future<void> _loadTimezones() async {
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      final all = await FlutterTimezone.getAvailableTimezones();
      if (!mounted) return;
      setState(() {
        _timezone = local.identifier;
        _timezones = all.map((t) => t.identifier).toList()..sort();
        _loadingTz = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _timezone = 'UTC';
        _timezones = const ['UTC'];
        _loadingTz = false;
      });
    }
  }

  Future<void> _pickTimezone() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            TimezonePicker(timezones: _timezones, selected: _timezone),
      ),
    );
    if (picked != null && mounted) setState(() => _timezone = picked);
  }

  /// One continuous flow: pick start then end on a single calendar (the range
  /// picker guarantees end >= start), instead of two disconnected pickers.
  Future<void> _pickRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(now.year + 5),
      initialDateRange: (_start != null && _end != null)
          ? DateTimeRange(start: _start!, end: _end!)
          : null,
      helpText: 'Select vacation dates',
      saveText: 'Done',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _start = picked.start;
      _end = picked.end;
    });
  }

  /// Dates on the first line, duration on a second line (so a long range never
  /// wraps mid-line).
  Widget _datesSubtitle(ThemeData theme) {
    if (_start == null || _end == null) {
      return const Text('Tap to choose start & end');
    }
    final days = _end!.difference(_start!).inDays + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Text('${_pretty(_start!)}  →  ${_pretty(_end!)}',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 2),
        Text('$days day${days == 1 ? '' : 's'}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _pretty(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  Future<void> _submit() async {
    final start = _start;
    final end = _end;
    final tz = _timezone;
    if (start == null || end == null || tz == null) return;
    if (start.isAfter(end)) {
      setState(() => _error = Problem.local(
            'Invalid dates',
            detail: 'Start date must be on or before the end date.',
          ));
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final controller = context.read<VacationController>();
    final res = await controller.create(start: start, end: end, timezone: tz);
    if (!mounted) return;
    switch (res) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final problem):
        setState(() {
          _submitting = false;
          _error = problem;
        });
    }
  }

  /// Friendly message for the failure cases zinc surfaces here. Note: zinc maps
  /// both TierInsufficient and ValidationError to HTTP 400, and the validation
  /// detail is the internal string "Invalid CreateVacationReq" — so we match on
  /// title/type/detail BEFORE falling back to the server's detail (otherwise the
  /// raw internal string would leak to the user).
  String _friendly(Problem p) {
    final type = p.type.toLowerCase();
    final title = p.title.toLowerCase();
    final detail = p.detail?.trim() ?? '';

    // Tier cap: zinc TierInsufficient (Title "Tier Insufficient", empty detail).
    if (type.contains('tier') ||
        title.contains('tier') ||
        title.contains('insufficient')) {
      return 'You’ve reached your yearly vacation limit for your plan.';
    }
    // Validation: overlap / out-of-order dates (detail = "Invalid CreateVacationReq").
    if (type.contains('validation') ||
        title.contains('validation') ||
        detail.startsWith('Invalid ')) {
      return 'That vacation window isn’t valid. It may overlap an existing one, '
          'or the dates are out of order.';
    }
    // Otherwise prefer a genuinely human server detail, else the title.
    return detail.isNotEmpty ? detail : p.title;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingTz) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final canSubmit =
        _start != null && _end != null && _timezone != null && !_submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule vacation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Pause all your habits for a date range.',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              isThreeLine: _start != null && _end != null,
              leading: const Icon(Icons.date_range, color: AppColors.vacation),
              title: const Text('Dates'),
              subtitle: _datesSubtitle(theme),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickRange,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Timezone'),
              subtitle:
                  Text((_timezone ?? 'UTC').replaceAll('_', ' ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTimezone,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _friendly(_error!),
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Schedule vacation'),
          ),
        ],
      ),
    );
  }
}

