import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// How the Today screen leads: with the next habit to do, or with the day's
/// progress across all habits.
enum TodayLayout { nextUp, progressList }

/// The user's Today layout choice, set in Profile. Persisted to an app-private
/// JSON file like [TimezonePreference]; falls back to [TodayLayout.nextUp]
/// when nothing is saved or the file can't be read.
class TodayLayoutSetting extends ValueNotifier<TodayLayout> {
  TodayLayoutSetting._() : super(TodayLayout.nextUp);

  static final instance = TodayLayoutSetting._();

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/today_layout.json');
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      value = TodayLayout.values.firstWhere(
        (l) => l.name == m['layout'],
        orElse: () => TodayLayout.nextUp,
      );
    } catch (_) {
      // Keep the default.
    }
  }

  Future<void> set(TodayLayout layout) async {
    value = layout;
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'layout': layout.name}));
    } catch (_) {
      // The choice still applies for this run.
    }
  }
}
