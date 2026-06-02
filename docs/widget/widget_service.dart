// PARKED — see docs/widget/README.md. Restore to lib/services/widget_service.dart
// when re-adding the home-screen widget (needs the home_widget package + App Group).
import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../generated/zinc/models/habit_overview_response.dart';

/// Bridges today's habit schedule to the iOS home-screen widget (WidgetKit) via a
/// shared App Group. The widget reads this and shows the next habit due, advancing
/// by time, then a done-summary. Rewritten whenever the dashboard overview loads.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _appGroup = 'group.cloud.atomi.alcoholNeon';
  static const _kind = 'NeonWidget';
  static const _dataKey = 'today_schedule';

  Future<void> sync(HabitOverviewResponse overview) async {
    try {
      await HomeWidget.setAppGroupId(_appGroup);
      final todayIndex = DateTime.now().weekday % 7; // Sun=0
      final items = <Map<String, dynamic>>[];
      var done = 0;
      var total = 0;
      for (final h in overview.habits ?? const []) {
        if (!h.enabled) continue;
        final days = h.days;
        if (days == null || todayIndex >= days.length || !days[todayIndex]) {
          continue;
        }
        total++;
        final isDone = h.status.isCompleteToday;
        if (isDone) done++;
        items.add({'time': _hm(h.notificationTime), 'name': h.name ?? 'Habit', 'done': isDone});
      }
      items.sort((a, b) => (a['time'] as String? ?? '99:99')
          .compareTo(b['time'] as String? ?? '99:99'));
      final payload = jsonEncode(
          {'date': _ymd(DateTime.now()), 'done': done, 'total': total, 'items': items});
      await HomeWidget.saveWidgetData<String>(_dataKey, payload);
      await HomeWidget.updateWidget(iOSName: _kind);
    } catch (_) {
      // Widget not installed / not iOS — non-critical.
    }
  }

  String? _hm(String? hhmmss) {
    if (hhmmss == null) return null;
    final p = hhmmss.split(':');
    if (p.length < 2) return null;
    return '${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}';
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
