import 'package:airwallex_payment_flutter/types/environment.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yaml/yaml.dart';

import 'dev_overrides.dart';
import 'landscape.dart';

/// Per-landscape configuration, loaded from layered YAML at startup:
///
///   `config/base.yaml`         defaults (also the effective config for `lapras`/local)
///   `config/<landscape>.yaml`  overrides base for pichu / pikachu / raichu
///   `--dart-define=NEON_*`     overrides everything (local dev / CI)
///
/// The landscape is chosen from the app's **own bundle id** (bundle-id-as-marker):
/// `…neon.pichu` → pichu, `…neon.pikachu` → pikachu, `…neon.raichu` → raichu; the
/// bare id falls back to raichu (release) / pichu (debug). `--dart-define=NEON_LANDSCAPE=…`
/// forces a landscape (e.g. `lapras` for local).
///
/// dart-define keys: NEON_LANDSCAPE, NEON_LOGTO_ENDPOINT, NEON_LOGTO_APP_ID,
/// NEON_ZINC_URL, NEON_ZINC_RESOURCE ("" → request no resource), NEON_AIRWALLEX_ENV.
class AppConfig {
  final Landscape landscape;
  final Uri zincBaseUrl;
  final String logtoEndpoint;
  final String logtoAppId;

  /// zinc API resource indicator. Empty string means "request no resource"
  /// (requesting one a Logto tenant lacks breaks the authorize request).
  final String zincResource;

  /// Airwallex native SDK environment (`demo` for dev, `production` for stage/prod).
  final Environment airwallexEnv;

  final String redirectUri;
  final List<String> scopes;

  const AppConfig({
    required this.landscape,
    required this.zincBaseUrl,
    required this.logtoEndpoint,
    required this.logtoAppId,
    required this.zincResource,
    required this.airwallexEnv,
    this.redirectUri = 'cloud.atomi.lapras.alcohol.neon://callback',
    this.scopes = const [
      'openid',
      'profile',
      'offline_access',
      'email',
      'admin',
      'active',
    ],
  });

  /// Resources to request at sign-in — empty when no zinc resource is configured.
  List<String> get apiResources =>
      zincResource.isEmpty ? const [] : [zincResource];

  /// The active config. Set once by [load] in `main()` before `runApp`.
  static late final AppConfig current;

  /// Loads [current]: picks the landscape from the app's own bundle id, layers
  /// `config/base.yaml` ← `config/<landscape>.yaml`, then applies `--dart-define`
  /// overrides. Await in `main()` before `runApp`.
  static Future<void> load() async {
    current = await resolveForPackage(
      (await PackageInfo.fromPlatform()).packageName,
      await DevOverrides.load(),
    );
  }

  /// Resolves the config for a given bundle id, layering optional dev-menu
  /// [overrides] (forced landscape + per-field overrides) on top of the YAML.
  /// Exposed for tests.
  @visibleForTesting
  static Future<AppConfig> resolveForPackage(
    String packageName, [
    DevOverrides overrides = const DevOverrides(),
  ]) async {
    final landscape = _resolveLandscape(packageName, overrides.landscape);
    final values = await _loadLayered(landscape);
    values.addAll(overrides.fields); // dev-menu field overrides beat YAML
    return _fromMap(landscape, values);
  }

  /// `config/base.yaml` ← `config/<landscape>.yaml` (lapras has no file → base only).
  static Future<Map<String, dynamic>> _loadLayered(Landscape l) async {
    final merged = _readYaml(await rootBundle.loadString('config/base.yaml'));
    if (l != Landscape.lapras) {
      merged.addAll(
        _readYaml(await rootBundle.loadString('config/${l.name}.yaml')),
      );
    }
    return merged;
  }

  static Map<String, dynamic> _readYaml(String src) {
    final doc = loadYaml(src);
    return doc is YamlMap
        ? Map<String, dynamic>.from(doc)
        : <String, dynamic>{};
  }

  static const _unset = '__neon_unset__';

  /// Builds an [AppConfig] from merged YAML [m], applying `--dart-define`
  /// overrides (an empty/unset define keeps the YAML value).
  static AppConfig _fromMap(Landscape landscape, Map<String, dynamic> m) {
    const dEndpoint = String.fromEnvironment('NEON_LOGTO_ENDPOINT');
    const dAppId = String.fromEnvironment('NEON_LOGTO_APP_ID');
    const dZincUrl = String.fromEnvironment('NEON_ZINC_URL');
    const dResource = String.fromEnvironment(
      'NEON_ZINC_RESOURCE',
      defaultValue: _unset,
    );
    const dAirwallex = String.fromEnvironment('NEON_AIRWALLEX_ENV');

    final zincUrl = dZincUrl.isEmpty ? '${m['zincBaseUrl']}' : dZincUrl;
    final endpoint = dEndpoint.isEmpty ? '${m['logtoEndpoint']}' : dEndpoint;
    final appId = dAppId.isEmpty ? '${m['logtoAppId']}' : dAppId;
    final resource = dResource == _unset ? '${m['zincResource']}' : dResource;
    final airwallex = dAirwallex.isEmpty ? '${m['airwallexEnv']}' : dAirwallex;
    final scopes =
        (m['scopes'] as List?)?.map((e) => '$e').toList() ?? const <String>[];

    return AppConfig(
      landscape: landscape,
      zincBaseUrl: Uri.parse(zincUrl),
      logtoEndpoint: endpoint,
      logtoAppId: appId,
      zincResource: resource,
      airwallexEnv: _parseAirwallexEnv(airwallex),
      redirectUri: '${m['redirectUri']}',
      scopes: scopes,
    );
  }

  /// Picks the [Landscape] from a `--dart-define=NEON_LANDSCAPE` override if set,
  /// else from the app's bundle id suffix, else prod (raichu) for release builds
  /// and dev (pichu) for debug.
  static Landscape _resolveLandscape(
    String packageName, [
    String? devLandscape,
  ]) {
    const override = String.fromEnvironment('NEON_LANDSCAPE');
    final name = override.isNotEmpty ? override : devLandscape;
    if (name != null && name.isNotEmpty) {
      for (final l in Landscape.values) {
        if (l.name == name) return l;
      }
    }
    // LPSM bundle id: cloud.atomi.<landscape>.<platform>.<service>[.<module>] —
    // the landscape is the segment right after the reversed domain.
    final parts = packageName.split('.');
    if (parts.length >= 3) {
      for (final l in Landscape.values) {
        if (parts[2] == l.name) return l;
      }
    }
    return kReleaseMode ? Landscape.raichu : Landscape.pichu;
  }

  /// Maps an Airwallex env string to an [Environment] (defaults to demo).
  static Environment _parseAirwallexEnv(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'production':
      case 'prod':
        return Environment.production;
      case 'staging':
        return Environment.staging;
      case 'preview':
        return Environment.preview;
      case 'demo':
      default:
        return Environment.demo;
    }
  }
}
