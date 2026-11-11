import 'dart:io';

import 'package:flutter/services.dart';

import '../features/dashboard/today_plan.dart';

/// Bridges the next open habit to the "Next up" Live Activity over the
/// `neon/live_activity` channel: the Lock Screen and Dynamic Island on iOS
/// (ios/Runner/LiveActivityBridge.swift), and an ongoing notification that
/// Android 16 promotes to a Live Update (NextUpNotification.kt). Best-effort:
/// failures never reach the UI.
class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  static const _channel = MethodChannel('neon/live_activity');

  /// Starts or updates the activity for [plan]'s next habit, or ends it when
  /// nothing is left to do today.
  Future<void> show(TodayPlan plan) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    final next = plan.next;
    final versionId = next?.habit.version.id;
    final deadline = next?.deadline;
    if (next == null || versionId == null || deadline == null) return end();
    try {
      await _channel.invokeMethod<void>('sync', {
        'versionId': versionId,
        'name': next.habit.name ?? 'Habit',
        'deadlineMs': deadline.millisecondsSinceEpoch,
        'stake': stakeLine(next.habit),
        'done': plan.done.length,
        'total': plan.scheduled,
      });
    } catch (_) {
      // No Live Activity support (older iOS, disabled) — non-critical.
    }
  }

  Future<void> end() async {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('end');
    } catch (_) {
      // Non-critical.
    }
  }
}
