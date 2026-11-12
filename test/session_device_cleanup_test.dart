import 'dart:async';

import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/features/dashboard/dashboard_controller.dart';
import 'package:alcohol_neon/services/widget_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'support/session_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const widgetChannel = MethodChannel('home_widget');
  const notificationChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezoneChannel = MethodChannel('flutter_timezone');
  late Map<String, dynamic> storage;
  late List<String> notifications;
  Future<void> Function(MethodCall)? beforeWidgetCall;
  Future<void> Function(MethodCall)? beforeNotificationCall;

  setUpAll(loadHarnessConfig);
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    PackageInfo.setMockInitialValues(
      appName: 'LazyTax',
      packageName: 'cloud.atomi.pichu.alcohol.neon.app',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    storage = {};
    notifications = [];
    beforeWidgetCall = null;
    beforeNotificationCall = null;
    messenger.setMockMethodCallHandler(widgetChannel, (call) async {
      await beforeWidgetCall?.call(call);
      final args = call.arguments as Map;
      if (call.method == 'saveWidgetData') {
        storage[args['id'] as String] = args['data'];
      }
      if (call.method == 'getWidgetData') return storage[args['id']];
      return true;
    });
    messenger.setMockMethodCallHandler(notificationChannel, (call) async {
      await beforeNotificationCall?.call(call);
      notifications.add(call.method);
      return true;
    });
    messenger.setMockMethodCallHandler(
      timezoneChannel,
      (_) async => 'Asia/Tokyo',
    );
  });

  tearDown(() {
    for (final channel in [
      widgetChannel,
      notificationChannel,
      timezoneChannel,
    ]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'session end removes schedule, auth, pending keys and cancels reminders',
    () async {
      final h = SessionHarness();
      await h.start();
      final c = DashboardController(h.session);
      await c.load();
      await Future<void>.delayed(Duration.zero);
      await h.session.syncDevice(h.session.generation, () async {});
      storage['pending_id'] = 'v1';
      storage['pending_at'] = 123.0;
      storage['failed_id'] = 'v2';
      expect(storage['zinc_uid'], 'user-1');
      expect(storage['today_schedule'], isNotNull);
      expect(notifications, contains('zonedSchedule'));
      await h.auth.signOut();
      await h.session.syncDevice(h.session.generation, () async {});
      for (final key in [
        'today_schedule',
        'zinc_base',
        'zinc_token',
        'zinc_uid',
        'pending_id',
        'pending_at',
        'failed_id',
      ]) {
        expect(storage[key], isNull, reason: key);
      }
      expect(notifications.last, 'cancelAll');
      expect(h.session.userId, isNull);
      expect(h.session.config, isNull);
      expect(h.session.consent, isNull);
      c.dispose();
      h.dispose();
    },
  );

  test(
    'an in-flight native write finishes before cleanup and next account sync',
    () async {
      final h = SessionHarness();
      await h.start();
      await h.session.syncDevice(h.session.generation, () async {});
      final started = Completer<void>();
      final release = Completer<void>();
      beforeWidgetCall = (call) async {
        if (call.method == 'saveWidgetData' &&
            (call.arguments as Map)['id'] == 'today_schedule' &&
            (call.arguments as Map)['data'] != null &&
            !started.isCompleted) {
          started.complete();
          await release.future;
        }
      };
      final old = DashboardController(h.session);
      await old.load();
      await started.future;
      await h.auth.signOut();
      h.auth.status = AuthStatus.authenticated;
      h.auth.uid = 'user-2';
      await h.session.bootstrap();
      release.complete();
      await h.session.syncDevice(h.session.generation, () async {});
      expect(storage['today_schedule'], isNull);
      expect(storage['zinc_token'], isNull);
      expect(notifications.last, 'cancelAll');
      final current = DashboardController(h.session);
      await current.load();
      await Future<void>.delayed(Duration.zero);
      await h.session.syncDevice(h.session.generation, () async {});
      expect(storage['zinc_uid'], 'user-2');
      expect(storage['today_schedule'], isNotNull);
      old.dispose();
      current.dispose();
      h.dispose();
    },
  );

  test(
    'late token from old dashboard cannot restore old auth after account switch',
    () async {
      final h = SessionHarness();
      await h.start();
      final lateToken = Completer<String?>();
      h.auth.token = () => lateToken.future;
      final old = DashboardController(h.session);
      await old.load();
      await h.auth.signOut();
      h.auth.status = AuthStatus.authenticated;
      h.auth.uid = 'user-2';
      h.auth.token = () async => 'new-token';
      await h.session.bootstrap();
      final current = DashboardController(h.session);
      await current.load();
      await Future<void>.delayed(Duration.zero);
      await h.session.syncDevice(h.session.generation, () async {});
      lateToken.complete('old-token');
      await Future<void>.delayed(Duration.zero);
      await h.session.syncDevice(h.session.generation, () async {});
      expect(storage['zinc_token'], 'new-token');
      expect(storage['zinc_uid'], 'user-2');
      old.dispose();
      current.dispose();
      h.dispose();
    },
  );

  test(
    'late overview after logout does not sync reminders or widget',
    () async {
      final response = Completer<http.Response>();
      final h = SessionHarness(
        respond: (r) async =>
            r.url.path.endsWith('/overview') ? response.future : null,
      );
      await h.start();
      await h.session.syncDevice(h.session.generation, () async {});
      notifications.clear();
      final c = DashboardController(h.session);
      final load = c.load();
      await h.auth.signOut();
      response.complete(jsonResponse(overviewBody()));
      await load;
      await h.session.syncDevice(h.session.generation, () async {});
      expect(storage['today_schedule'], isNull);
      expect(notifications.where((m) => m == 'zonedSchedule'), isEmpty);
      c.dispose();
      h.dispose();
    },
  );

  test(
    'logout while permission is pending never schedules old reminders',
    () async {
      final h = SessionHarness();
      await h.start();
      await h.session.syncDevice(h.session.generation, () async {});
      final started = Completer<void>();
      final release = Completer<void>();
      beforeNotificationCall = (call) async {
        if (call.method == 'requestPermissions') {
          started.complete();
          await release.future;
        }
      };
      notifications.clear();
      final c = DashboardController(h.session);
      await c.load();
      await started.future;
      await h.auth.signOut();
      release.complete();
      await h.session.syncDevice(h.session.generation, () async {});
      expect(notifications.where((m) => m == 'zonedSchedule'), isEmpty);
      expect(notifications.last, 'cancelAll');
      expect(storage['zinc_token'], isNull);
      c.dispose();
      h.dispose();
    },
  );

  test('null auth token replaces a previously cached token', () async {
    storage['zinc_token'] = 'expired';
    await WidgetService.instance.cacheAuth(
      baseUrl: 'https://zinc.test',
      token: null,
      userId: 'user-1',
    );
    expect(storage['zinc_token'], isNull);
    expect(storage['zinc_uid'], 'user-1');
  });
}
