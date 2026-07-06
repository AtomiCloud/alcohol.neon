import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../generated/zinc/models/habit_overview_response.dart';

/// Bridges today's habit schedule to the iOS home-screen widget (WidgetKit) via a
/// shared App Group. The widget reads this and shows the next habit due, advancing
/// by time, then a done-summary. Rewritten whenever the dashboard overview loads.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _kind = 'NeonWidget';
  static const _dataKey = 'today_schedule';

  /// Per-landscape App Group — `group.<app bundle id>` (LPSM). Matches the
  /// NEON_APP_GROUP build setting the iOS targets sign with.
  static String? _appGroupCache;
  static Future<String> _appGroup() async => _appGroupCache ??=
      'group.${(await PackageInfo.fromPlatform()).packageName}';

  Future<void> sync(HabitOverviewResponse overview) async {
    try {
      await HomeWidget.setAppGroupId(await _appGroup());
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
        items.add({
          'id': h
              .version
              .id, // habit version id — the widget's Complete button completes this
          'time': _hm(h.notificationTime),
          'name': h.name ?? 'Habit',
          'done': isDone,
        });
      }
      items.sort(
        (a, b) => (a['time'] as String? ?? '99:99').compareTo(
          b['time'] as String? ?? '99:99',
        ),
      );
      final payload = jsonEncode({
        'date': _ymd(DateTime.now()),
        'done': done,
        'total': total,
        'items': items,
      });
      await HomeWidget.saveWidgetData<String>(_dataKey, payload);
      await HomeWidget.updateWidget(iOSName: _kind);
    } catch (_) {
      // Widget not installed / not iOS — non-critical.
    }
  }

  /// Cache the auth context the widget's "Complete" button needs to POST a completion
  /// to zinc directly (Swift URLSession). The access token is short-lived; we refresh
  /// it here on every dashboard load. If it's stale when the widget is tapped, the POST
  /// 401s and the optimistic tick is rolled back. Best-effort.
  Future<void> cacheAuth({
    required String baseUrl,
    required String? token,
    required String? userId,
  }) async {
    try {
      await HomeWidget.setAppGroupId(await _appGroup());
      await HomeWidget.saveWidgetData<String>('zinc_base', baseUrl);
      if (token != null) {
        await HomeWidget.saveWidgetData<String>('zinc_token', token);
      }
      if (userId != null) {
        await HomeWidget.saveWidgetData<String>('zinc_uid', userId);
      }
    } catch (_) {
      // Non-critical.
    }
  }

  /// Undo an optimistic completion the widget applied locally (Swift flips the item
  /// to done instantly on tap). Called when the background zinc completion fails, so
  /// the tick doesn't lie about a habit the server never recorded. Best-effort.
  Future<void> revertDone(String versionId) async {
    try {
      await HomeWidget.setAppGroupId(await _appGroup());
      final raw = await HomeWidget.getWidgetData<String>(_dataKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final items =
          (map['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      var changed = false;
      for (final it in items) {
        if (it['id'] == versionId && it['done'] == true) {
          it['done'] = false;
          map['done'] = ((map['done'] as int?) ?? 1) - 1;
          changed = true;
        }
      }
      if (!changed) return;
      await HomeWidget.saveWidgetData<String>(_dataKey, jsonEncode(map));
      await HomeWidget.updateWidget(iOSName: _kind);
    } catch (_) {
      // Non-critical.
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
