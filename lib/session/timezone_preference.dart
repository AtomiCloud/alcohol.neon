import 'dart:convert';
import 'dart:io';

import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';

import '../data/config_repository.dart';

/// Whether the user's Configuration.Timezone should be moved to the phone's
/// timezone: only while "Follow phone timezone" is on, the phone reports a
/// timezone, and it differs from the configured one.
bool shouldSyncTimezone({
  required bool followPhone,
  required String? deviceTimezone,
  required String? configuredTimezone,
}) =>
    followPhone &&
    deviceTimezone != null &&
    deviceTimezone.isNotEmpty &&
    deviceTimezone != configuredTimezone;

/// The device's IANA timezone (e.g. `Asia/Singapore`) via `flutter_timezone`,
/// as onboarding uses; `null` when the platform can't report one.
Future<String?> deviceTimezone() async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    return null;
  }
}

/// The local "Follow phone timezone" preference (default ON). Persisted to an
/// app-private JSON file, like [DevOverrides]. Turned OFF when the user picks a
/// timezone by hand in Settings; turning it back ON re-syncs to the phone.
/// Injected into [SessionController] so tests can replace the file I/O.
class TimezonePreference {
  const TimezonePreference();

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/timezone_preference.json');
  }

  Future<bool> loadFollowPhone() async {
    try {
      final f = await _file();
      if (!await f.exists()) return true;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return m['followPhone'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> saveFollowPhone(bool followPhone) async {
    final f = await _file();
    await f.writeAsString(jsonEncode({'followPhone': followPhone}));
  }
}

/// What to tell the user after a timezone change settled days that had already
/// ended in the new timezone, one sentence per day, e.g. "Your timezone changed
/// to Singapore. Tuesday had already ended there, so a freeze covered it."
/// Null when the change settled nothing.
String? timezoneSettledMessage(
  String timezone,
  List<TimezoneSettledCheck> settled,
) {
  if (settled.isEmpty) return null;
  // Protections are per user and date, so every habit on a date shares a status;
  // if they ever differ, report the worst.
  const rank = {'vacation': 0, 'frozen': 1, 'missed': 2};
  final byDate = <DateTime, String>{};
  for (final c in settled) {
    final current = byDate[c.date];
    if (current == null || (rank[c.status] ?? 2) > (rank[current] ?? 2)) {
      byDate[c.date] = c.status;
    }
  }
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final place = timezone.split('/').last.replaceAll('_', ' ');
  final dates = byDate.keys.toList()..sort();
  final sentences = dates.map((date) {
    final day = days[date.weekday - 1];
    return switch (byDate[date]) {
      'vacation' =>
        '$day had already ended there, so your vacation covered it.',
      'frozen' => '$day had already ended there, so a freeze covered it.',
      _ =>
        '$day had already ended there and no freeze was left, so it was missed.',
    };
  });
  return 'Your timezone changed to $place. ${sentences.join(' ')}';
}
