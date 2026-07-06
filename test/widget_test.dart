// Foundation smoke tests. Real feature tests come with the habit screens.
import 'package:flutter_test/flutter_test.dart';

import 'package:airwallex_payment_flutter/types/environment.dart';
import 'package:alcohol_neon/config/app_config.dart';
import 'package:alcohol_neon/config/landscape.dart';
import 'package:alcohol_neon/core/problem.dart';

void main() {
  // Needed so AppConfig can load the config/*.yaml assets via rootBundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'AppConfig resolves landscape + layered config from its bundle id',
    () async {
      final config = await AppConfig.resolveForPackage(
        'cloud.atomi.pichu.alcohol.neon',
      );
      expect(config.landscape, Landscape.pichu);
      expect(config.redirectUri, 'cloud.atomi.pichu.alcohol.neon://callback');
      expect(config.logtoEndpoint, contains('pichu')); // from pichu.yaml
      expect(config.logtoAppId, 'k19tbzmnsndxnt1v6rfkm'); // from pichu.yaml
      expect(config.scopes, contains('openid')); // inherited from base.yaml
    },
  );

  test(
    'AppConfig resolves raichu from its raichu bundle id landscape segment',
    () async {
      final config = await AppConfig.resolveForPackage(
        'cloud.atomi.raichu.alcohol.neon',
      );
      expect(config.landscape, Landscape.raichu);
      expect(config.redirectUri, 'cloud.atomi.raichu.alcohol.neon://callback');
      expect(
        config.airwallexEnv,
        Environment.production,
      ); // overrides base demo
    },
  );

  test('apiResources is empty when no zinc resource is configured', () {
    final base = Uri.parse('https://example.com');
    final withResource = AppConfig(
      landscape: Landscape.pichu,
      zincBaseUrl: base,
      logtoEndpoint: 'e',
      logtoAppId: 'a',
      zincResource: 'https://api.zinc.alcohol.pichu',
      airwallexEnv: Environment.demo,
    );
    final withoutResource = AppConfig(
      landscape: Landscape.pichu,
      zincBaseUrl: base,
      logtoEndpoint: 'e',
      logtoAppId: 'a',
      zincResource: '',
      airwallexEnv: Environment.demo,
    );
    expect(withResource.apiResources, ['https://api.zinc.alcohol.pichu']);
    expect(withoutResource.apiResources, isEmpty);
  });

  test('AppConfig resolves an Airwallex environment per landscape', () async {
    final config = await AppConfig.resolveForPackage(
      'cloud.atomi.pikachu.alcohol.neon',
    );
    expect(config.landscape, Landscape.pikachu);
    expect(config.airwallexEnv, Environment.production);
  });

  test('Result pattern matching', () {
    Result<int> r = const Ok(42);
    final value = switch (r) {
      Ok(:final value) => value,
      Err() => -1,
    };
    expect(value, 42);
  });
}
