import 'package:alcohol_neon/features/friends/friends_view.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

/// Friends → Enter a code, against a mocked zinc. Invites are permanent and
/// using one sends the owner a friend request, so the screen must never claim
/// you're friends until zinc says so, and never mention expiry.
void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  const timezoneChannel = MethodChannel('flutter_timezone');

  setUpAll(loadHarnessConfig);
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'LazyTax',
      packageName: 'cloud.atomi.pichu.alcohol.neon.app',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    messenger.setMockMethodCallHandler(timezoneChannel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(timezoneChannel, null));

  Future<void> enterCode(
    WidgetTester tester,
    http.Response acceptResponse,
  ) async {
    final h = SessionHarness(
      respond: (req) async {
        final path = req.url.path;
        if (path.endsWith('/invites/ab23cdefgh/accept')) return acceptResponse;
        if (path.endsWith('/Friend/user-1')) return jsonResponse([]);
        if (path.endsWith('/Friend/user-1/requests')) {
          return jsonResponse({'incoming': [], 'outgoing': []});
        }
        return null;
      },
    );
    await h.start();
    await tester.pumpWidget(
      ChangeNotifierProvider<SessionController>.value(
        value: h.session,
        child: MaterialApp(theme: AppTheme.light, home: const FriendsView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('7 days'), findsNothing);
    expect(find.textContaining('friend request'), findsOneWidget);

    await tester.tap(find.text('Enter a code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'AB23cdefgh');
    await tester.tap(find.text('Add friend'));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    });
  }

  testWidgets('a sent request says so, not that you are friends', (
    tester,
  ) async {
    await enterCode(tester, jsonResponse({'relation': 'outgoing'}));
    expect(
      find.text('Friend request sent. You’ll be friends once they accept.'),
      findsOneWidget,
    );
    expect(find.textContaining('now friends'), findsNothing);
  });

  testWidgets('they had already asked you: you are friends', (tester) async {
    await enterCode(tester, jsonResponse({'relation': 'friend'}));
    expect(find.text('You’re now friends.'), findsOneWidget);
  });

  testWidgets('older zinc (FriendRes, no relation) reads as friends', (
    tester,
  ) async {
    await enterCode(
      tester,
      jsonResponse({'userId': 'u2', 'username': 'sam', 'sinceUtc': null}),
    );
    expect(find.text('You’re now friends.'), findsOneWidget);
  });

  testWidgets('an unknown code is invalid, never "expired"', (tester) async {
    await enterCode(
      tester,
      jsonResponse({'title': 'Not Found', 'status': 404}, 404),
    );
    expect(find.textContaining('isn’t valid'), findsOneWidget);
    expect(find.textContaining('expired'), findsNothing);
  });
}
