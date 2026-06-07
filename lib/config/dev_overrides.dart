import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Developer overrides, persisted to a JSON file and layered on top of the YAML +
/// `--dart-define` config. Set via the hidden dev menu (see DevConfigView), read
/// once by [AppConfig.load] at startup. Lets you point a build at a different
/// landscape or tweak individual config values without rebuilding.
class DevOverrides {
  /// Forces a landscape (by name), overriding the one derived from the bundle id.
  final String? landscape;

  /// Overrides individual AppConfig fields (zincBaseUrl, logtoEndpoint,
  /// logtoAppId, zincResource, airwallexEnv, redirectUri, …) — same keys as the
  /// YAML files.
  final Map<String, String> fields;

  const DevOverrides({this.landscape, this.fields = const {}});

  bool get isEmpty => landscape == null && fields.isEmpty;

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/dev_overrides.json');
  }

  static Future<DevOverrides> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return const DevOverrides();
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final raw = (m['fields'] as Map?) ?? const {};
      return DevOverrides(
        landscape: m['landscape'] as String?,
        fields: {for (final e in raw.entries) '${e.key}': '${e.value}'},
      );
    } catch (_) {
      return const DevOverrides();
    }
  }

  Future<void> save() async {
    final f = await _file();
    await f.writeAsString(
      jsonEncode({'landscape': landscape, 'fields': fields}),
    );
  }

  static Future<void> clear() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}
