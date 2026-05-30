// Foundation smoke tests. Real feature tests come with the habit screens.
import 'package:flutter_test/flutter_test.dart';

import 'package:alcohol_neon/config/app_config.dart';
import 'package:alcohol_neon/config/landscape.dart';
import 'package:alcohol_neon/core/problem.dart';

void main() {
  test('AppConfig.current resolves a landscape with defaults', () {
    final config = AppConfig.current;
    expect(Landscape.values.contains(config.landscape), isTrue);
    expect(config.redirectUri, 'cloud.atomi.alcohol.neon://callback');
    expect(config.logtoEndpoint, isNotEmpty);
  });

  test('apiResources is empty when no zinc resource is configured', () {
    final base = Uri.parse('https://example.com');
    final withResource = AppConfig(
      landscape: Landscape.pichu,
      zincBaseUrl: base,
      logtoEndpoint: 'e',
      logtoAppId: 'a',
      zincResource: 'https://api.zinc.alcohol.pichu',
    );
    final withoutResource = AppConfig(
      landscape: Landscape.pichu,
      zincBaseUrl: base,
      logtoEndpoint: 'e',
      logtoAppId: 'a',
      zincResource: '',
    );
    expect(withResource.apiResources, ['https://api.zinc.alcohol.pichu']);
    expect(withoutResource.apiResources, isEmpty);
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
