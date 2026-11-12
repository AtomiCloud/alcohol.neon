import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_format.dart';
import '../../session/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/glass_page.dart';
import 'vacation_controller.dart';
import 'vacation_create_view.dart';

/// M7, the vacation windows screen. The active vacation leads, with how long
/// is left and End today; upcoming ones follow as a list you swipe to
/// delete; past ones fold away. Scheduling is a + in the top bar on iOS and a
/// floating button on Android.
class VacationListView extends StatelessWidget {
  const VacationListView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          VacationController(ctx.read<SessionController>())..load(),
      child: const _VacationPage(),
    );
  }
}

class _VacationPage extends StatefulWidget {
  const _VacationPage();

  @override
  State<_VacationPage> createState() => _VacationPageState();
}

class _VacationPageState extends State<_VacationPage> {
  bool _showPast = false;

  Future<void> _openCreate(VacationController c) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: c,
        child: const VacationCreateView(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.watch<VacationController>();
    final ready = c.phase == VacationPhase.ready;
    final ios = isCupertino(context);
    final t = GlassTokens.of(context);
    return GlassPage(
      title: 'Vacations',
      onRefresh: ready ? c.load : null,
      actions: [
        if (ready && ios)
          GlassIconButton(
            icon: Icons.add_rounded,
            label: 'Schedule vacation',
            onTap: () => _openCreate(c),
          ),
      ],
      floatingActionButton: ready && !ios && c.items.isNotEmpty
          ? FloatingActionButton(
              tooltip: 'Schedule vacation',
              backgroundColor: t.accent,
              foregroundColor: t.onAccent,
              elevation: 2,
              onPressed: () => _openCreate(c),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      children: switch (c.phase) {
        VacationPhase.loading => const [
          SizedBox(height: 320, child: AppLoader()),
        ],
        VacationPhase.error => [
          GlassBanner(
            icon: Icons.cloud_off_rounded,
            title: c.error?.displayMessage ?? 'Could not load vacations',
            error: true,
            action: GlassTextButton(label: 'Retry', onPressed: c.load),
          ),
        ],
        VacationPhase.ready => _content(c),
      },
    );
  }

  List<Widget> _content(VacationController c) {
    final active = c.items.where((i) => i.status == VacationStatus.active);
    final upcoming = c.items.where((i) => i.status == VacationStatus.upcoming);
    final past = c.items.where((i) => i.status == VacationStatus.ended).toList()
      ..sort((a, b) => _start(b).compareTo(_start(a)));
    final ios = isCupertino(context);
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
      if (c.items.isEmpty) ...[
        const SizedBox(height: 8),
        _Empty(onSchedule: () => _openCreate(c)),
      ],
      for (final item in active) ...[
        const SizedBox(height: 8),
        _ActiveCard(item: item, controller: c),
      ],
      if (upcoming.isNotEmpty) ...[
        GlassSection(
          title: 'Coming up',
          children: [
            for (final item in upcoming)
              _UpcomingRow(item: item, controller: c),
          ],
        ),
        GlassFooter(
          ios
              ? 'Swipe a vacation left to delete it. One that has started '
                    'can only be ended.'
              : 'Swipe a vacation away, or press and hold it, to delete it. '
                    'One that has started can only be ended.',
        ),
      ],
      if (past.isNotEmpty)
        GlassSection(
          title: 'Past',
          children: _showPast
              ? [
                  for (final item in past)
                    GlassRow(
                      leading: const Icon(Icons.event_rounded),
                      title: vacationRange(item, weekday: false),
                      subtitle: vacationMeta(item),
                    ),
                  GlassRow(
                    title: 'Hide',
                    centered: true,
                    chevron: false,
                    onTap: () => setState(() => _showPast = false),
                  ),
                ]
              : [
                  GlassRow(
                    leading: const Icon(Icons.history_rounded),
                    title:
                        '${past.length} past vacation${past.length == 1 ? '' : 's'}',
                    value: 'Show',
                    onTap: () => setState(() => _showPast = true),
                  ),
                ],
        ),
    ];
  }
}

DateTime _start(VacationItem i) =>
    tryParseStandardDate(i.res.startDate) ?? DateTime(0);

const _months = [
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
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _longDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "10 – 15 Nov", "28 Dec – 3 Jan" or, with [weekday], "Thu 24 – Mon 28 Dec".
/// The year shows only when it isn't this year.
String dateRange(DateTime s, DateTime e, {bool weekday = false}) {
  String day(DateTime d) =>
      weekday ? '${_days[d.weekday - 1]} ${d.day}' : '${d.day}';
  final year = e.year == DateTime.now().year ? '' : ' ${e.year}';
  final sameMonth = s.month == e.month && s.year == e.year;
  final from = sameMonth ? day(s) : '${day(s)} ${_months[s.month - 1]}';
  return '$from – ${day(e)} ${_months[e.month - 1]}$year';
}

String vacationRange(VacationItem i, {bool weekday = true}) {
  final s = tryParseStandardDate(i.res.startDate);
  final e = tryParseStandardDate(i.res.endDate);
  if (s == null || e == null) return 'Unknown dates';
  return dateRange(s, e, weekday: weekday);
}

/// "5 days · Singapore": the length, both ends included, and the timezone's
/// city.
String vacationMeta(VacationItem i) {
  final s = tryParseStandardDate(i.res.startDate);
  final e = tryParseStandardDate(i.res.endDate);
  final tz = i.res.timezone;
  return [
    if (s != null && e != null) daysLabel(e.difference(s).inDays + 1),
    if (tz != null && tz.isNotEmpty) tz.split('/').last.replaceAll('_', ' '),
  ].join(' · ');
}

String daysLabel(int n) => '$n day${n == 1 ? '' : 's'}';

/// "Monday 16 Nov".
String longDate(DateTime d) =>
    '${_longDays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

class _ActiveCard extends StatelessWidget {
  final VacationItem item;
  final VacationController controller;
  const _ActiveCard({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final end = tryParseStandardDate(item.res.endDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final left = end == null ? null : end.difference(today).inDays + 1;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: t.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
            ),
          ),
        ],
      ),
    );
    return Glass(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'On vacation now',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.vacation,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (left != null)
                Text(
                  left <= 1 ? 'Last day' : '$left days left',
                  style: theme.textTheme.labelLarge?.copyWith(color: t.muted),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            vacationRange(item, weekday: false),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          line(
            Icons.pause_circle_outline_rounded,
            end == null
                ? 'Every habit is paused.'
                : 'Every habit is paused. They resume on '
                      '${longDate(end.add(const Duration(days: 1)))}.',
          ),
          line(Icons.public_rounded, vacationMeta(item)),
          const SizedBox(height: 16),
          GlassButton(
            label: 'End today',
            secondary: true,
            busy: controller.isBusy(item.id),
            onPressed: () async {
              final ok = await showGlassConfirm(
                context,
                title: 'End vacation today?',
                message: 'Your habits resume tomorrow.',
                confirmLabel: 'End today',
                destructive: false,
              );
              if (ok) await controller.endToday(item.id);
            },
          ),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final VacationItem item;
  final VacationController controller;
  const _UpcomingRow({required this.item, required this.controller});

  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showGlassConfirm(
      context,
      title: 'Delete this vacation?',
      message: '${vacationRange(item)} is removed.',
      confirmLabel: 'Delete',
    );
    if (ok) await controller.remove(item.id);
    // The refreshed list drops the row; Dismissible must not remove it too.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final busy = controller.isBusy(item.id);
    final row = GlassRow(
      leading: const Icon(Icons.event_rounded),
      title: vacationRange(item),
      subtitle: vacationMeta(item),
      trailing: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
    return Dismissible(
      key: ValueKey('vacation-${item.id}'),
      direction: busy ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Text(
          'Delete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      child: isCupertino(context)
          ? row
          : GestureDetector(
              onLongPress: busy ? null : () => _confirmDelete(context),
              child: row,
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onSchedule;
  const _Empty({required this.onSchedule});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    return Glass(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.vacation.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(
              dimension: 56,
              child: Icon(
                Icons.beach_access_rounded,
                size: 28,
                color: AppColors.vacation,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No vacations planned',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pause every habit for a date range. Nothing is missed or '
            'charged while you’re away.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: 'Schedule a vacation',
              onPressed: onSchedule,
            ),
          ),
        ],
      ),
    );
  }
}
