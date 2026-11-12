import 'dart:convert';

import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/config/app_config.dart';
import 'package:alcohol_neon/generated/zinc/models/configuration_principal_res.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_overview_response.dart';
import 'package:alcohol_neon/networking/api_client.dart';
import 'package:alcohol_neon/session/session_cache.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/session/timezone_preference.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

Future<void> loadHarnessConfig() async {
  AppConfig.current = await AppConfig.resolveForPackage(
    'cloud.atomi.pichu.alcohol.neon.app',
  );
}

const habitVersion = {
  'id': 'v1',
  'habitId': 'h1',
  'version': 1,
  'task': 'Read a chapter',
  'daysOfWeek': ['Monday'],
  'notificationTime': '22:00:00',
  'stake': '0',
  'charityId': 'ch1',
  'timezone': 'America/New_York',
};

Map<String, Object?> overviewBody([String status = 'not_applicable']) => {
  'usedSkip': 0,
  'totalSkip': 3,
  'totalDebt': '0.00',
  'habits': [
    {
      'id': 'h1',
      'name': 'Read a chapter',
      'enabled': true,
      'timezone': 'America/New_York',
      'notificationTime': '22:00:00',
      'days': List.filled(7, true),
      'stake': {'amount': 0, 'currency': 'USD'},
      'charity': {'name': 'Red Cross'},
      'version': {'id': 'v1', 'version': 1, 'isActive': true},
      'timeLeftToEodMinutes': 120,
      'status': {
        'currentStreak': 4,
        'maxStreak': 9,
        'isCompleteToday': status == 'succeeded',
        'today': '09-11-2026',
        'todayStatus': status,
        'week': <String, Object?>{},
      },
    },
  ],
};

class HarnessAuth extends ChangeNotifier implements AuthService {
  HarnessAuth(this.client);
  final http.Client client;
  String uid = 'user-1';
  Future<String?> Function()? token;
  @override
  AuthStatus status = AuthStatus.authenticated;
  @override
  AppConfig get config => AppConfig.current;
  @override
  Future<UserClaims?> claims() async => UserClaims(sub: uid);
  @override
  Future<String?> zincAccessToken() => token?.call() ?? Future.value('token');
  @override
  Future<String?> idToken() async => 'id-token';
  @override
  ApiClient makeApiClient() => ApiClient(
    baseUrl: Uri.parse('https://zinc.test'),
    tokenProvider: () async => 'token',
    client: client,
  );
  @override
  Future<void> signOut() async {
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory "Follow phone timezone" preference: the file-backed default does
/// real I/O, which never completes inside testWidgets' fake async zone.
class MemoryTimezonePreference extends TimezonePreference {
  MemoryTimezonePreference([this.followPhone = true]);
  bool followPhone;
  @override
  Future<bool> loadFollowPhone() async => followPhone;
  @override
  Future<void> saveFollowPhone(bool value) async => followPhone = value;
}

/// In-memory [SessionCache], for the same reason as [MemoryTimezonePreference].
class MemorySessionCache extends SessionCache {
  MemorySessionCache([this.snapshot]);
  SessionSnapshot? snapshot;
  ConfigurationPrincipalRes? savedConfig;
  HabitOverviewResponse? savedOverview;
  @override
  Future<SessionSnapshot?> load(String userId, {DateTime? now}) async =>
      snapshot;
  @override
  Future<void> saveConfig(String userId, ConfigurationPrincipalRes c) async =>
      savedConfig = c;
  @override
  Future<void> saveOverview(String userId, HabitOverviewResponse o) async =>
      savedOverview = o;
  @override
  Future<void> clear() async => snapshot = null;
}

/// Real session/repositories with HTTP replaced at their public boundary.
class SessionHarness {
  SessionHarness({this.respond, bool followPhone = true})
    : timezonePreference = MemoryTimezonePreference(followPhone) {
    client = MockClient((request) async {
      requests.add(request);
      final custom = await respond?.call(request);
      if (custom != null) return custom;
      final path = request.url.path;
      if (path.endsWith('/User/Me/All')) {
        return jsonResponse({
          'principal': {'emailVerified': true, 'active': true},
        });
      }
      if (path.endsWith('/Configuration/me')) {
        return jsonResponse({
          'principal': {
            'id': 'cfg1',
            'timezone': 'Asia/Singapore',
            'defaultCharityId': 'ch1',
          },
          'charity': {'id': 'ch1', 'name': 'Red Cross'},
        });
      }
      if (path.endsWith('/consent')) {
        return jsonResponse({'hasPaymentConsent': false});
      }
      if (path.endsWith('/overview')) return jsonResponse(overviewBody());
      if (path.contains('/Protection/')) {
        return jsonResponse({'balance': 2, 'cap': 5});
      }
      if (path.endsWith('/Charity/ch1')) {
        return jsonResponse({
          'principal': {'id': 'ch1', 'name': 'Red Cross'},
        });
      }
      if (path.contains('/Habit/') && path.endsWith('/h1')) {
        return jsonResponse(habitVersion);
      }
      if (request.method == 'POST' && path.contains('/executions')) {
        return jsonResponse({
          'id': 'e1',
          'habitVersionId': 'v1',
          'paymentProcessed': false,
        });
      }
      return jsonResponse({'title': 'Not found', 'status': 404}, 404);
    });
    auth = HarnessAuth(client);
    session = SessionController(
      auth,
      timezonePreference: timezonePreference,
      cache: cache,
    );
  }

  final Future<http.Response?> Function(http.Request)? respond;
  final MemoryTimezonePreference timezonePreference;
  final MemorySessionCache cache = MemorySessionCache();
  final requests = <http.Request>[];
  late final http.Client client;
  late final HarnessAuth auth;
  late final SessionController session;

  Future<void> start() => session.bootstrap();

  void dispose() {
    session.dispose();
    auth.dispose();
    client.close();
  }
}
