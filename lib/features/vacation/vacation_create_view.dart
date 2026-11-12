import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_page.dart';
import '../settings/timezone_picker.dart';
import 'vacation_controller.dart';
import 'vacation_list_view.dart';

/// M7, schedule a vacation window on one page: a summary of what pausing
/// means, an inline calendar (tap the first day, then the last; formatted to
/// zinc's `dd-MM-yyyy` by the controller), and the timezone, defaulting to
/// the device's (reusing Settings' [TimezonePicker]). Pops `true` on success.
/// Reads its [VacationController] from the provider supplied by the list.
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

  /// Tap the first day, then the last. A tap before the first day moves it;
  /// a tap once both are set starts again.
  void _tapDay(DateTime d) => setState(() {
    final start = _start;
    if (start == null || _end != null || d.isBefore(start)) {
      _start = d;
      _end = null;
    } else {
      _end = d;
    }
    _error = null;
  });

  Future<void> _submit() async {
    final start = _start;
    final end = _end;
    final tz = _timezone;
    if (start == null || end == null || tz == null) return;
    if (start.isAfter(end)) {
      setState(
        () => _error = Problem.local(
          'Invalid dates',
          detail: 'Start date must be on or before the end date.',
        ),
      );
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
    return p.displayMessage;
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit =
        _start != null && _end != null && _timezone != null && !_submitting;
    return GlassPage(
      title: 'Schedule vacation',
      dock: _loadingTz
          ? null
          : GlassButton(
              label: 'Schedule vacation',
              busy: _submitting,
              onPressed: canSubmit ? _submit : null,
            ),
      children: _loadingTz
          ? const [SizedBox(height: 320, child: AppLoader())]
          : [
              if (_error case final error?)
                GlassBanner(
                  icon: Icons.error_outline_rounded,
                  title: _friendly(error),
                  error: true,
                ),
              const SizedBox(height: 8),
              _Summary(start: _start, end: _end),
              GlassHeading('Dates'),
              Glass(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: RangeCalendar(start: _start, end: _end, onTap: _tapDay),
              ),
              GlassFooter(
                _start != null && _end == null
                    ? 'Now tap the last day.'
                    : 'Tap the first day, then the last.',
              ),
              GlassSection(
                title: 'Timezone',
                children: [
                  GlassRow(
                    leading: const Icon(Icons.public_rounded),
                    title: timezoneLabel(_timezone ?? 'UTC'),
                    subtitle: 'Dates start and end at midnight here',
                    onTap: _pickTimezone,
                  ),
                ],
              ),
            ],
    );
  }
}

String timezoneLabel(String id) => id.split('/').last.replaceAll('_', ' ');

/// What the chosen dates mean, like Today's Next up card.
class _Summary extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  const _Summary({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final s = start, e = end;
    final (tag, title, body) = switch ((s, e)) {
      (final s?, final e?) => (
        daysLabel(e.difference(s).inDays + 1),
        dateRange(s, e, weekday: true),
        'Every habit pauses. Nothing is missed or charged. Habits resume '
            '${longDate(e.add(const Duration(days: 1)))}.',
      ),
      (final s?, null) => (
        'Starts ${longDate(s)}',
        'Choose the last day',
        'Every habit pauses from the first day to the last.',
      ),
      _ => (
        'New vacation',
        'Choose your dates',
        'Every habit pauses. Nothing is missed or charged while you’re away.',
      ),
    };
    return Glass(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag,
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.vacation,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.pause_circle_outline_rounded,
                size: 16,
                color: t.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A month grid for picking a date range from today on, Monday first.
class RangeCalendar extends StatefulWidget {
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onTap;
  const RangeCalendar({
    super.key,
    required this.start,
    required this.end,
    required this.onTap,
  });

  @override
  State<RangeCalendar> createState() => _RangeCalendarState();
}

class _RangeCalendarState extends State<RangeCalendar> {
  static const _monthNames = [
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

  late final DateTime _today = () {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }();
  late DateTime _month = DateTime(
    (widget.start ?? _today).year,
    (widget.start ?? _today).month,
  );

  bool get _canGoBack => _month.isAfter(DateTime(_today.year, _today.month));

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final lead = DateTime(_month.year, _month.month).weekday - 1;
    final count = DateUtils.getDaysInMonth(_month.year, _month.month);
    final s = widget.start, e = widget.end;
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_monthNames[_month.month - 1]} ${_month.year}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Previous month',
              onPressed: _canGoBack ? () => _shift(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
              color: t.accent,
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => _shift(1),
              icon: const Icon(Icons.chevron_right_rounded),
              color: t.accent,
            ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Center(
                child: Text(
                  d,
                  style: theme.textTheme.labelMedium?.copyWith(color: t.muted),
                ),
              ),
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var day = 1; day <= count; day++)
              _cell(context, DateTime(_month.year, _month.month, day), s, e),
          ],
        ),
      ],
    );
  }

  Widget _cell(BuildContext context, DateTime d, DateTime? s, DateTime? e) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final past = d.isBefore(_today);
    final isStart = s != null && DateUtils.isSameDay(d, s);
    final isEnd = e != null && DateUtils.isSameDay(d, e);
    final inside = s != null && e != null && !d.isBefore(s) && !d.isAfter(e);
    final edge = isStart || isEnd;
    final today = DateUtils.isSameDay(d, _today);
    final band = inside && !(isStart && isEnd)
        ? BoxDecoration(
            color: t.accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(isStart || d.weekday == 1 ? 20 : 0),
              right: Radius.circular(isEnd || d.weekday == 7 ? 20 : 0),
            ),
          )
        : null;
    return Semantics(
      button: !past,
      selected: edge,
      label: '${d.day} ${_monthNames[d.month - 1]}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: past ? null : () => widget.onTap(d),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: DecoratedBox(
            decoration: band ?? const BoxDecoration(),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: edge ? t.accent : null,
                  border: today && !edge
                      ? Border.all(color: t.accent, width: 1.2)
                      : null,
                ),
                child: Text(
                  '${d.day}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: edge
                        ? t.onAccent
                        : past
                        ? t.muted.withValues(alpha: 0.45)
                        : null,
                    fontWeight: edge ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
