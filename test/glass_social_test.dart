import 'dart:convert';

import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/features/friends/friends_view.dart';
import 'package:alcohol_neon/features/inbox/inbox_view.dart';
import 'package:alcohol_neon/features/strava/strava_view.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/app_theme.dart';
import 'package:alcohol_neon/widgets/glass_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

const platforms = [TargetPlatform.iOS, TargetPlatform.android];

Future<void> pump(
  WidgetTester tester,
  SessionHarness h,
  Widget home, {
  required TargetPlatform platform,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(value: h.session),
        ChangeNotifierProvider<AuthService>.value(value: h.auth),
      ],
      child: MaterialApp(
        theme: AppTheme.light.copyWith(platform: platform),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });
}

Iterable<http.Request> calls(SessionHarness h, String method, String path) =>
    h.requests.where((r) => r.method == method && r.url.path.endsWith(path));

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  const timezoneChannel = MethodChannel('flutter_timezone');
  const linkMethods = MethodChannel('com.llfbandit.app_links/messages');
  const linkEvents = MethodChannel('com.llfbandit.app_links/events');

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
    messenger.setMockMethodCallHandler(linkMethods, (_) async => null);
    messenger.setMockMethodCallHandler(linkEvents, (_) async => null);
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(timezoneChannel, null);
    messenger.setMockMethodCallHandler(linkMethods, null);
    messenger.setMockMethodCallHandler(linkEvents, null);
  });

  group('Friends', () {
    Future<http.Response?> friends(http.Request r) async {
      final path = r.url.path;
      if (path.endsWith('/Friend/user-1')) {
        return jsonResponse([
          {'userId': 'u-sam', 'username': 'sam'},
        ]);
      }
      if (path.endsWith('/Friend/user-1/requests')) {
        return jsonResponse({
          'incoming': [
            {'userId': 'u-priya', 'username': 'priya'},
          ],
          'outgoing': [
            {'userId': 'u-jonas', 'username': 'jonas'},
          ],
        });
      }
      if (path.endsWith('/Friend/user-1/search')) {
        return jsonResponse([
          {'userId': 'u-aria', 'username': 'aria', 'relation': 'none'},
          {'userId': 'u-arjun', 'username': 'arjun', 'relation': 'friend'},
        ]);
      }
      if (r.method == 'DELETE' || r.method == 'POST') {
        return jsonResponse({'relation': 'outgoing'});
      }
      return null;
    }

    testWidgets('requests come before the invite, and search shows only '
        'results, each with its one action', (tester) async {
      final h = SessionHarness(respond: friends);
      await h.start();
      await pump(tester, h, const FriendsView(), platform: TargetPlatform.iOS);

      final requests = tester.getTopLeft(find.text('Requests')).dy;
      final invite = tester.getTopLeft(find.text('Invite a friend')).dy;
      expect(requests, lessThan(invite));
      expect(find.widgetWithText(GlassButton, 'Accept'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ar');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Requests'), findsNothing);
      expect(find.text('Invite a friend'), findsNothing);
      expect(find.text('People'), findsOneWidget);
      // A friend has nothing to do; a stranger has Add.
      expect(find.widgetWithText(GlassButton, 'Add'), findsOneWidget);
      await tester.tap(find.widgetWithText(GlassButton, 'Add'));
      await tester.pumpAndSettle();
      final sent =
          jsonDecode(calls(h, 'POST', '/Friend/user-1/requests').single.body)
              as Map;
      expect(sent['toUserId'], 'u-aria');
    });

    for (final platform in platforms) {
      final ios = platform == TargetPlatform.iOS;
      testWidgets('${platform.name}: removing a friend goes through the more '
          'button${ios ? '' : ' menu'} and asks first', (tester) async {
        final h = SessionHarness(respond: friends);
        await h.start();
        await pump(tester, h, const FriendsView(), platform: platform);

        expect(find.byTooltip('Remove friend'), findsNothing);
        await tester.scrollUntilVisible(
          find.byTooltip('More for sam'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('More for sam'));
        await tester.pumpAndSettle();
        if (!ios) {
          await tester.tap(find.text('Remove friend'));
          await tester.pumpAndSettle();
        }
        expect(find.text('Remove sam?'), findsOneWidget);
        expect(calls(h, 'DELETE', '/u-sam'), isEmpty);
        await tester.tap(
          ios
              ? find.widgetWithText(CupertinoActionSheetAction, 'Remove friend')
              : find.widgetWithText(TextButton, 'Remove friend'),
        );
        await tester.pumpAndSettle();
        expect(calls(h, 'DELETE', '/Friend/user-1/u-sam'), hasLength(1));
      });
    }

    testWidgets('an invite code is entered in a sheet, not a dialog', (
      tester,
    ) async {
      final h = SessionHarness(respond: friends);
      await h.start();
      await pump(
        tester,
        h,
        const FriendsView(),
        platform: TargetPlatform.android,
      );
      await tester.tap(find.text('Have a code? Enter it'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Enter an invite'), findsOneWidget);
    });
  });

  group('Inbox', () {
    final now = DateTime.now().toUtc();
    Future<http.Response?> inbox(http.Request r) async {
      final path = r.url.path;
      if (r.method == 'GET' && path.endsWith('/Inbox/user-1')) {
        return jsonResponse([
          {
            'id': 'n1',
            'kind': 'friend_request',
            'title': 'priya wants to be friends',
            'body': '',
            'data': jsonEncode({'fromUserId': 'u-priya'}),
            'createdAtUtc': now.toIso8601String(),
          },
          {
            'id': 'n2',
            'kind': 'friend_accepted',
            'title': 'sam accepted your request',
            'body': '',
            'createdAtUtc': now
                .subtract(const Duration(days: 3))
                .toIso8601String(),
            'readAtUtc': now.toIso8601String(),
          },
        ]);
      }
      if (path.endsWith('/read-all')) return jsonResponse(1);
      if (path.endsWith('/accept')) {
        return jsonResponse({'userId': 'u-priya', 'username': 'priya'});
      }
      if (r.method == 'POST') return http.Response('', 204);
      return null;
    }

    testWidgets('groups by day, answers requests in place, and marks all '
        'read from the bar', (tester) async {
      final h = SessionHarness(respond: inbox);
      await h.start();
      await pump(tester, h, const InboxView(), platform: TargetPlatform.iOS);

      final today = tester.getTopLeft(find.text('Today')).dy;
      final earlier = tester.getTopLeft(find.text('Earlier')).dy;
      final request = tester
          .getTopLeft(find.text('priya wants to be friends'))
          .dy;
      final accepted = tester
          .getTopLeft(find.text('sam accepted your request'))
          .dy;
      expect(today, lessThan(request));
      expect(request, lessThan(earlier));
      expect(earlier, lessThan(accepted));

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();
      expect(calls(h, 'POST', '/Inbox/user-1/read-all'), hasLength(1));
      await tester.tap(find.widgetWithText(GlassButton, 'Accept'));
      await tester.pumpAndSettle();
      expect(
        calls(h, 'POST', '/Friend/user-1/requests/u-priya/accept'),
        hasLength(1),
      );
      expect(find.text('You’re now friends'), findsOneWidget);
    });
  });

  group('Strava', () {
    Future<http.Response?> connected(http.Request r) async {
      final path = r.url.path;
      if (path.endsWith('/Strava/user-1')) {
        return r.method == 'DELETE'
            ? http.Response('', 204)
            : jsonResponse({
                'connected': true,
                'connectedAtUtc': '2026-11-04T08:00:00Z',
              });
      }
      if (path.endsWith('/Subscription/user-1')) {
        return jsonResponse({'tier': 'pro'});
      }
      return null;
    }

    for (final platform in platforms) {
      final ios = platform == TargetPlatform.iOS;
      testWidgets('${platform.name}: Disconnect is a red row that asks with '
          '${ios ? 'an action sheet' : 'a dialog'}', (tester) async {
        final h = SessionHarness(respond: connected);
        await h.start();
        await pump(tester, h, const StravaView(), platform: platform);

        expect(find.text('Habits check themselves off'), findsOneWidget);
        expect(find.byType(OutlinedButton), findsNothing);
        await tester.tap(find.text('Disconnect Strava'));
        await tester.pumpAndSettle();
        expect(
          find.byType(ios ? CupertinoActionSheet : AlertDialog),
          findsOneWidget,
        );
        expect(calls(h, 'DELETE', '/Strava/user-1'), isEmpty);
        await tester.tap(
          ios
              ? find.widgetWithText(CupertinoActionSheetAction, 'Disconnect')
              : find.widgetWithText(TextButton, 'Disconnect'),
        );
        await tester.pumpAndSettle();
        expect(calls(h, 'DELETE', '/Strava/user-1'), hasLength(1));
      });
    }

    testWidgets('the consent screen keeps Connect in the bottom bar', (
      tester,
    ) async {
      final h = SessionHarness();
      await h.start();
      await pump(
        tester,
        h,
        const StravaConsentView(),
        platform: TargetPlatform.iOS,
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.bottomNavigationBar, isNotNull);
      expect(
        find.descendant(
          of: find.byWidget(scaffold.bottomNavigationBar!),
          matching: find.byType(ConnectWithStravaButton),
        ),
        findsOneWidget,
      );
    });
  });
}
