import 'package:alcohol_neon/core/problem.dart';
import 'package:alcohol_neon/networking/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Guards the error-display rule: zinc can send RFC 7807 problems whose
/// `detail` is an EMPTY string (e.g. TierInsufficient before it grew a default
/// detail). An empty string is non-null, so `detail ?? title` renders invisible
/// text — [Problem.displayMessage] must fall back to the title instead.
void main() {
  group('Problem.displayMessage', () {
    test('returns the detail when it carries real text', () {
      const p = Problem(
        type: 'about:blank',
        title: 'Tier Insufficient',
        status: 400,
        detail: 'Your free plan allows up to 2 habits.',
      );
      expect(p.displayMessage, 'Your free plan allows up to 2 habits.');
    });

    test('falls back to the title when detail is null', () {
      const p = Problem(type: 'about:blank', title: 'Error', status: 500);
      expect(p.displayMessage, 'Error');
    });

    test('falls back to the title when detail is an empty string', () {
      const p = Problem(
        type:
            'https://api.zinc.alcohol.pichu.cluster.atomi.cloud'
            '/docs/pichu/alcohol/zinc/main/v1/tier_insufficient',
        title: 'Tier Insufficient',
        status: 400,
        detail: '',
      );
      expect(p.displayMessage, 'Tier Insufficient');
    });

    test('falls back to the title when detail is only whitespace', () {
      const p = Problem(
        type: 'about:blank',
        title: 'Error',
        status: 400,
        detail: '   ',
      );
      expect(p.displayMessage, 'Error');
    });

    test('trims surrounding whitespace from a real detail', () {
      const p = Problem(
        type: 'about:blank',
        title: 'Error',
        status: 400,
        detail: '  Something went wrong.  ',
      );
      expect(p.displayMessage, 'Something went wrong.');
    });
  });

  group('ApiClient error bodies', () {
    const nginx404 =
        '<html>\r\n<head><title>404 Not Found</title></head>\r\n<body>\r\n'
        '<center><h1>404 Not Found</h1></center>\r\n<hr><center>nginx</center>'
        '\r\n</body>\r\n</html>\r\n';

    ApiClient client(http.Response res) => ApiClient(
      baseUrl: Uri.parse('https://zinc.test'),
      tokenProvider: () async => 'token',
      client: MockClient((_) async => res),
    );

    Problem problemOf(Result<Object?> r) => switch (r) {
      Err(:final problem) => problem,
      Ok() => fail('expected an error'),
    };

    test('a proxy HTML page never reaches the user verbatim', () async {
      final api = client(
        http.Response(nginx404, 404, headers: {'content-type': 'text/html'}),
      );
      for (final r in [
        await api.get('/api/v1.0/Habit/h1', (j) => j),
        await api.delete('/api/v1.0/Habit/h1'),
      ]) {
        final p = problemOf(r);
        expect(p.status, 404);
        expect(p.displayMessage, isNot(contains('<')));
        expect(p.displayMessage, isNot(contains('nginx')));
        expect(p.displayMessage, contains('HTTP 404'));
      }
    });

    test('zinc RFC 7807 problems still pass through', () async {
      final api = client(
        http.Response(
          '{"title":"Habit limit","status":402,"detail":"Your free plan allows up to 2 habits."}',
          402,
          headers: {'content-type': 'application/problem+json'},
        ),
      );
      final p = problemOf(await api.get('/x', (j) => j));
      expect(p.status, 402);
      expect(p.displayMessage, 'Your free plan allows up to 2 habits.');
    });
  });
}
