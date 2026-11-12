import 'dart:convert';

import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/config/app_config.dart';
import 'package:alcohol_neon/core/problem.dart';
import 'package:alcohol_neon/data/execution_repository.dart';
import 'package:alcohol_neon/data/habit_repository.dart';
import 'package:alcohol_neon/data/protection_repository.dart';
import 'package:alcohol_neon/features/dashboard/dashboard_view.dart';
import 'package:alcohol_neon/generated/zinc/models/configuration_principal_res.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_overview_response.dart';
import 'package:alcohol_neon/networking/api_client.dart';
import 'package:alcohol_neon/session/session_cache.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

class _Auth implements AuthService {
  @override
  Future<String?> zincAccessToken() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Session extends ChangeNotifier implements SessionController {
  _Session(this.api);
  final ApiClient api;
  @override
  String get userId => 'user-1';
  @override
  int get generation => 0;
  @override
  Future<void> syncDevice(
    int generation,
    Future<void> Function() action,
  ) async {}
  @override
  AuthService get auth => _Auth();
  @override
  HabitRepository get habits => HabitRepository(api);
  @override
  ExecutionRepository get executions => ExecutionRepository(api);
  @override
  ProtectionRepository get protections => ProtectionRepository(api);
  @override
  String? takeTimezoneNotice() => null;
  @override
  ConfigurationPrincipalRes? get config => null;
  @override
  HabitOverviewResponse? takeCachedOverview() => null;
  @override
  Future<Result<HabitOverviewResponse>>? takeOverviewPrefetch() => null;
  @override
  SessionCache get cache => _cache;
  final _cache = MemorySessionCache();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    AppConfig.current = await AppConfig.resolveForPackage(
      'cloud.atomi.pichu.alcohol.neon.app',
    );
  });

  for (final state in [
    (status: 'not_applicable', label: 'Complete'),
    (status: 'succeeded', label: 'Completed today'),
    (status: 'skip', label: 'Skipped today'),
    (status: 'vacation', label: 'On vacation'),
    (status: 'frozen', label: 'Covered by a freeze today'),
    (status: 'rest', label: 'Rest day'),
    (status: 'missing', label: "Today's status unavailable"),
  ]) {
    testWidgets('habit date drives ${state.label}, not phone or user week', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // Make the server date differ from the device weekday on every run.
      final deviceDay = DateTime.now().weekday % 7;
      final serverDay = (deviceDay + 1) % 7;
      final serverDate = DateTime(2026, 1, 4 + serverDay);
      final date = '${serverDate.day.toString().padLeft(2, '0')}-01-2026';
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode(
            request.url.path.endsWith('/overview')
                ? {
                    'usedSkip': 0,
                    'totalSkip': 3,
                    'totalDebt': '0.00',
                    'habits': [
                      {
                        'id': 'h1',
                        'name': 'Read a chapter',
                        'enabled': true,
                        'timezone': 'Asia/Singapore',
                        'notificationTime': '22:00',
                        'days': List.generate(
                          7,
                          (i) =>
                              i ==
                              (state.status == 'rest' ? deviceDay : serverDay),
                        ),
                        'stake': {'amount': 3, 'currency': 'USD'},
                        'charity': {'name': 'Red Cross'},
                        'version': {'id': 'v1', 'version': 1, 'isActive': true},
                        'timeLeftToEodMinutes': 120,
                        'status': {
                          'currentStreak': 4, 'maxStreak': 9,
                          // Deliberately contradictory legacy fields: neither should drive today.
                          'isCompleteToday': state.status == 'not_applicable',
                          'week': {
                            for (final day in [
                              'sunday',
                              'monday',
                              'tuesday',
                              'wednesday',
                              'thursday',
                              'friday',
                              'saturday',
                            ])
                              day: 'skip',
                          },
                          if (state.status != 'missing') ...{
                            'today': date,
                            'todayStatus': state.status == 'rest'
                                ? 'not_applicable'
                                : state.status,
                          },
                        },
                      },
                    ],
                  }
                : {'balance': 2, 'cap': 5},
          ),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final session = _Session(
        ApiClient(
          baseUrl: Uri.parse('https://zinc.test'),
          tokenProvider: () async => 'token',
          client: client,
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<SessionController>.value(
          value: session,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const DashboardView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(state.label), findsOneWidget);
      expect(
        find.text('Complete'),
        state.status == 'not_applicable' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Skip'),
        state.status == 'not_applicable' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
      client.close();
    });
  }
}
