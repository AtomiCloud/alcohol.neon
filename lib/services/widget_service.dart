import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../features/dashboard/today_plan.dart';

/// Bridges today's habit schedule to the home-screen widgets: iOS (WidgetKit) via a
/// shared App Group, Android (TodayWidget.kt) via home_widget's preferences. The widget reads this and shows the next habit due, advancing
/// by time, then a done-summary. Rewritten whenever the dashboard overview loads.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _kind = 'NeonWidget';

  /// The Android widget providers (android/.../TodayWidget.kt), by class name:
  /// the app id differs per flavor, so home_widget can't derive them.
  static const _androidWidgets = [
    'cloud.atomi.alcohol_neon.NextUpWidget',
    'cloud.atomi.alcohol_neon.TodayWidget',
  ];
  static const _dataKey = 'today_schedule';

  /// Per-landscape App Group — `group.<app bundle id>` (LPSM). Matches the
  /// NEON_APP_GROUP build setting the iOS targets sign with.
  static String? _appGroupCache;
  static Future<String> _appGroup() async => _appGroupCache ??=
      'group.${(await PackageInfo.fromPlatform()).packageName}';

  /// Redraw the iOS widget and both Android widgets.
  static Future<void> _refresh() async {
    if (!Platform.isAndroid) {
      await HomeWidget.updateWidget(iOSName: _kind);
      return;
    }
    for (final name in _androidWidgets) {
      await HomeWidget.updateWidget(qualifiedAndroidName: name);
    }
  }

  /// Remove all account-owned widget state, including optimistic native actions.
  Future<void> clear() async {
    try {
      await HomeWidget.setAppGroupId(await _appGroup());
      for (final key in [
        _dataKey,
        'zinc_base',
        'zinc_token',
        'zinc_uid',
        'pending_id',
        'pending_at',
        // The widget's "Couldn't save. Try again." marker (TodayWidget.kt).
        'failed_id',
      ]) {
        await HomeWidget.saveWidgetData<Object>(key, null);
      }
      await _refresh();
    } catch (_) {
      // Widget not installed / not supported — non-critical.
    }
  }

  /// Write today's plan for the widget: the open habits soonest deadline first
  /// (the user's order breaking ties), then the ones settled today in the
  /// user's order. Each open item
  /// carries its deadline (UTC) and proof, so the widget can count down and drop
  /// a habit once its check has closed.
  Future<void> sync(TodayPlan plan) async {
    try {
      await HomeWidget.setAppGroupId(await _appGroup());
      await HomeWidget.saveWidgetData<String>(
        _dataKey,
        jsonEncode(widgetSchedule(plan, DateTime.now())),
      );
      await _refresh();
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
      await HomeWidget.saveWidgetData<String>('zinc_token', token);
      await HomeWidget.saveWidgetData<String>('zinc_uid', userId);
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
      await _refresh();
    } catch (_) {
      // Non-critical.
    }
  }
}

/// The App Group payload the widget reads (`today_schedule`). `id` is the habit
/// version the Complete button posts to; `done` and the top-level `done` count
/// are what [CompleteHabitIntent] and [WidgetService.revertDone] flip.
Map<String, Object?> widgetSchedule(TodayPlan plan, DateTime now) => {
  'date':
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
  'done': plan.done.length,
  'total': plan.scheduled,
  'items': [
    for (final i in plan.soonest)
      {
        'id': i.habit.version.id,
        'name': i.habit.name ?? 'Habit',
        'done': false,
        'deadline': i.deadline!.toUtc().toIso8601String(),
        // Unknown proofs (e.g. a newer plugin) show as a plain check-in.
        'proof': i.habit.proof == 'nfc' ? 'nfc' : 'manual',
      },
    for (final i in plan.done)
      {'id': i.habit.version.id, 'name': i.habit.name ?? 'Habit', 'done': true},
  ],
};
