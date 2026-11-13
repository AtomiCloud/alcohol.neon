import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// The user's Appearance choice, set in Profile: follow the phone
/// ([ThemeMode.system], the default), or always light or dark. A device
/// preference, not synced to zinc, persisted to an app-private JSON file like
/// [TodayLayoutSetting]; it survives relaunch and sign-out.
class AppearanceSetting extends ValueNotifier<ThemeMode> {
  /// [directory] is where the choice is saved; app support by default.
  AppearanceSetting({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory,
      super(ThemeMode.system);

  static final instance = AppearanceSetting();

  final Future<Directory> Function() _directory;

  Future<File> _file() async =>
      File('${(await _directory()).path}/appearance.json');

  Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      value = ThemeMode.values.firstWhere(
        (mode) => mode.name == m['themeMode'],
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      // Keep the default.
    }
  }

  Future<void> set(ThemeMode mode) async {
    value = mode;
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({'themeMode': mode.name}));
    } catch (_) {
      // The choice still applies for this run.
    }
  }
}
