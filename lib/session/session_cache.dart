import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../generated/zinc/models/configuration_principal_res.dart';
import '../generated/zinc/models/habit_overview_response.dart';

/// What the last launch saw: the user's configuration and Today's overview.
class SessionSnapshot {
  final ConfigurationPrincipalRes config;
  final HabitOverviewResponse overview;
  final DateTime savedAt;
  const SessionSnapshot(this.config, this.overview, this.savedAt);
}

/// Saves the configuration and Today's overview to an app-private JSON file so
/// the next launch can show Today at once and refresh it in the background.
/// Keyed by user id and only used on the day it was saved, so a different
/// account or yesterday's statuses never show. Best-effort: any I/O or decode
/// failure behaves like an empty cache.
class SessionCache {
  final Future<Directory> Function() _dir;
  const SessionCache({Future<Directory> Function()? dir})
    : _dir = dir ?? getApplicationSupportDirectory;

  Future<File> _file() async =>
      File('${(await _dir()).path}/session_cache.json');

  Future<Map<String, dynamic>?> _read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String userId, String key, Object value) async {
    try {
      final old = await _read();
      final m = old != null && old['userId'] == userId
          ? old
          : <String, dynamic>{'userId': userId};
      m[key] = value;
      if (key == 'overview') m['savedAt'] = DateTime.now().toIso8601String();
      await (await _file()).writeAsString(jsonEncode(m));
    } catch (_) {
      // Only costs the next launch its instant Today.
    }
  }

  /// The snapshot for [userId] if it is complete and was saved on [now]'s day.
  Future<SessionSnapshot?> load(String userId, {DateTime? now}) async {
    final m = await _read();
    if (m == null || m['userId'] != userId) return null;
    try {
      final savedAt = DateTime.parse(m['savedAt'] as String).toLocal();
      final today = (now ?? DateTime.now()).toLocal();
      if (savedAt.year != today.year ||
          savedAt.month != today.month ||
          savedAt.day != today.day) {
        return null;
      }
      return SessionSnapshot(
        ConfigurationPrincipalRes.fromJson(
          (m['config'] as Map).cast<String, Object?>(),
        ),
        HabitOverviewResponse.fromJson(
          (m['overview'] as Map).cast<String, Object?>(),
        ),
        savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveConfig(String userId, ConfigurationPrincipalRes config) =>
      _write(userId, 'config', config);

  Future<void> saveOverview(String userId, HabitOverviewResponse overview) =>
      _write(userId, 'overview', overview);

  /// Called on sign-out so the next account starts clean.
  Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
