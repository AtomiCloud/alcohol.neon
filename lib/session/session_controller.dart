import 'package:flutter/foundation.dart';

import '../auth/auth_service.dart';
import '../core/launch_timeline.dart';
import '../core/problem.dart';
import '../data/cause_repository.dart';
import '../data/charity_repository.dart';
import '../data/config_repository.dart';
import '../data/execution_repository.dart';
import '../data/habit_repository.dart';
import '../data/nfc_tag_repository.dart';
import '../data/payment_repository.dart';
import '../data/protection_repository.dart';
import '../data/subscription_repository.dart';
import '../data/user_repository.dart';
import '../data/vacation_repository.dart';
import '../generated/zinc/models/configuration_principal_res.dart';
import '../generated/zinc/models/payment_consent_res.dart';
import '../generated/zinc/models/update_configuration_req.dart';
import '../networking/api_client.dart';
import '../services/notification_service.dart';
import '../services/live_activity_service.dart';
import '../services/widget_service.dart';
import 'timezone_preference.dart';

/// Where the signed-in user is in the bootstrap → configured journey.
enum SessionPhase { idle, bootstrapping, needsOnboarding, ready, error }

/// Runs the post-sign-in bootstrap (plan §6A): provision the zinc user, then load
/// configuration — routing to onboarding when absent. Owns the zinc repositories so
/// features share one [ApiClient]. Provided after [AuthService] (see main.dart).
class SessionController extends ChangeNotifier {
  final AuthService auth;
  final UserRepository users;
  final ConfigRepository configs;
  final CharityRepository charities;
  final CauseRepository causes;
  final HabitRepository habits;
  final ExecutionRepository executions;
  final PaymentRepository payments;
  final ProtectionRepository protections;
  final VacationRepository vacations;
  final SubscriptionRepository subscriptions;
  final NfcTagRepository nfcTags;

  /// Stores the "Follow phone timezone" preference (file-backed by default).
  final TimezonePreference timezonePreference;

  SessionController(
    AuthService auth, {
    TimezonePreference timezonePreference = const TimezonePreference(),
  }) : this._(auth, auth.makeApiClient(), timezonePreference);

  SessionController._(this.auth, ApiClient api, this.timezonePreference)
    : users = UserRepository(api),
      configs = ConfigRepository(api),
      charities = CharityRepository(api),
      causes = CauseRepository(api),
      habits = HabitRepository(api),
      executions = ExecutionRepository(api),
      payments = PaymentRepository(api),
      protections = ProtectionRepository(api),
      vacations = VacationRepository(api),
      subscriptions = SubscriptionRepository(api),
      nfcTags = NfcTagRepository(api) {
    auth.addListener(_onAuthChanged);
  }

  int _generation = 0;
  int get generation => _generation;
  Future<void> _deviceWork = Future.value();

  /// Serialize native writes and cleanup: a logout that races a platform call
  /// must clear *after* that call finishes, before the next account can sync.
  Future<void> syncDevice(int generation, Future<void> Function() action) {
    return _deviceWork = _deviceWork
        .then((_) async {
          if (generation != _generation ||
              auth.status != AuthStatus.authenticated) {
            return;
          }
          await action();
        })
        .catchError((Object _) {
          debugPrint('Could not sync optional device integrations.');
        });
  }

  void _clearSession() {
    _generation++;
    _userId = null;
    _config = null;
    _timezoneNotice = null;
    _consent = null;
    _timezoneSync = null;
    _error = null;
    _phase = SessionPhase.idle;
    _deviceWork = _deviceWork.then((_) async {
      await WidgetService.instance.clear();
      await LiveActivityService.instance.end();
      try {
        await NotificationService.instance.cancelAll();
      } catch (_) {
        debugPrint('Could not cancel optional device notifications.');
      }
    });
  }

  void _onAuthChanged() {
    if (auth.status == AuthStatus.authenticated) return;
    _clearSession();
    notifyListeners();
  }

  @override
  void dispose() {
    auth.removeListener(_onAuthChanged);
    _generation++;
    super.dispose();
  }

  SessionPhase _phase = SessionPhase.idle;
  Problem? _error;
  String? _userId;
  ConfigurationPrincipalRes? _config;
  PaymentConsentRes? _consent;
  bool _followPhoneTimezone = true;
  Future<bool>? _timezoneSync;
  String? _timezoneNotice;

  SessionPhase get phase => _phase;
  Problem? get error => _error;

  /// zinc user id (== Logto `sub`). Cached for the `/{userId}/…` endpoints in later
  /// milestones (habits, payments).
  String? get userId => _userId;
  ConfigurationPrincipalRes? get config => _config;

  /// Returns and clears the message for days the last timezone sync settled
  /// (see [timezoneSettledMessage]); the dashboard shows it once.
  String? takeTimezoneNotice() {
    final notice = _timezoneNotice;
    _timezoneNotice = null;
    return notice;
  }

  /// The user's cached payment consent (`GET /Payment/{userId}/consent`), loaded
  /// during bootstrap and refreshed via [refreshConsent]. `null` until first loaded
  /// (or if the load failed).
  PaymentConsentRes? get consent => _consent;

  /// Whether the user currently has an active payment consent on file. This is the
  /// single source of truth for gating staked habits — derived from the zinc
  /// `/consent` GET, **never** the Logto JWT claim (which can be stale).
  bool get hasPaymentConsent => _consent?.hasPaymentConsent ?? false;

  /// The local "Follow phone timezone" preference (default ON), loaded during
  /// bootstrap. While ON, [syncDeviceTimezone] keeps Configuration.Timezone —
  /// zinc's timezone for every daily habit check — equal to the phone's.
  bool get followPhoneTimezone => _followPhoneTimezone;

  /// Provision the user (idempotent) then resolve configuration. Safe to re-run
  /// (e.g. on retry, or re-entering the authed shell after a previous sign-in).
  Future<void> bootstrap() async {
    _clearSession();
    final generation = _generation;
    _error = null;
    _setPhase(SessionPhase.bootstrapping);

    final claims = await auth.claims();
    if (generation != _generation) return;
    _userId = claims?.sub;

    // Fetch the access token first: if it's expired the SDK refreshes via the
    // refresh token, which also re-stores a fresh id_token. Reading idToken after
    // that means a mid-session expiry self-heals instead of sending a stale token
    // to POST /User (zinc validates the id_token's lifetime).
    LaunchTimeline.mark('bootstrap-claims');
    final accessToken = await auth.zincAccessToken();
    final idToken = await auth.idToken();
    LaunchTimeline.mark('bootstrap-tokens');
    if (generation != _generation) return;
    if (idToken == null || accessToken == null) {
      return _fail(
        Problem.local(
          'Could not read sign-in tokens',
          type: 'neon:auth',
          detail:
              'No id/access token available after sign-in. Try signing in again.',
        ),
      );
    }

    // Ensure the zinc user exists. We check with GET /User/Me/All first rather than
    // blindly POSTing: POST /User is create-only (INSERT on the JWT sub) and throws a
    // server-side UniqueConstraintException + error log on every returning sign-in.
    // So: 200 ⇒ already provisioned; 404 ⇒ first sign-in, create now.
    final me = await users.me();
    if (generation != _generation) return;
    if (me case Err(:final problem)) {
      if (problem.status == 404) {
        final created = await users.create(
          idToken: idToken,
          accessToken: accessToken,
        );
        if (generation != _generation) return;
        // Tolerate a 409 in case of a concurrent first-sign-in race.
        if (created case Err(
          problem: final p,
        ) when p.status != 409 && !p.title.toLowerCase().contains('conflict')) {
          return _fail(p);
        }
      } else {
        return _fail(problem);
      }
    }

    // Device-local preference; loaded before onboarding too so a hand-picked
    // onboarding timezone can turn it off.
    final followPhone = await timezonePreference.loadFollowPhone();
    if (generation != _generation) return;
    _followPhoneTimezone = followPhone;

    final cfg = await configs.mine();
    if (generation != _generation) return;
    switch (cfg) {
      case Ok(:final value):
        _config = value.principal;
        // Follow the phone before the app shows anything, so the dashboard's
        // first load (and the reminders it plans) already uses the new timezone.
        await syncDeviceTimezone();
        if (generation != _generation) return;
        // Load payment consent up front so the habit editor can gate staked
        // habits synchronously (off `hasPaymentConsent`). Best-effort: a failure
        // here leaves consent unknown but must not block reaching the app — the
        // editor falls back to running the consent flow on demand.
        await _loadConsent();
        if (generation != _generation) return;
        LaunchTimeline.mark('bootstrap-ready');
        _setPhase(SessionPhase.ready);
      case Err(:final problem):
        // 404 ⇒ no configuration yet ⇒ onboard. Anything else is a real error.
        if (problem.status == 404) {
          _setPhase(SessionPhase.needsOnboarding);
        } else {
          _fail(problem);
        }
    }
  }

  /// Best-effort load of the payment consent into the cache (no notify; the caller
  /// flips the phase). Tolerates failure — leaves the previous cache intact.
  Future<void> _loadConsent() async {
    final uid = _userId;
    final generation = _generation;
    if (uid == null) return;
    final res = await payments.consent(uid);
    if (generation != _generation) return;
    if (res case Ok(:final value)) _consent = value;
  }

  /// Re-reads `GET /Payment/{userId}/consent` and refreshes the cached consent so
  /// dependent screens (habit editor gate, settings consent card) reflect a newly
  /// set-up or revoked payment method. Returns the result so the caller can surface
  /// a failure; on success it notifies listeners. Leaves the cache intact when the
  /// refresh fails. Truth is always this GET, never the Logto claim.
  Future<Result<PaymentConsentRes>> refreshConsent() async {
    final uid = _userId;
    final generation = _generation;
    if (uid == null) return const Err(Problem.unauthenticated);
    final res = await payments.consent(uid);
    if (generation != _generation) return const Err(Problem.unauthenticated);
    switch (res) {
      case Ok(:final value):
        _consent = value;
        notifyListeners();
        return Ok(value);
      case Err(:final problem):
        return Err(problem);
    }
  }

  /// Called by onboarding once `POST /Configuration` succeeds.
  void onConfigured(ConfigurationPrincipalRes config) {
    _config = config;
    _setPhase(SessionPhase.ready);
  }

  /// Re-reads `GET /Configuration/me` and refreshes the cached principal so
  /// dependent screens (dashboard / habit defaults) see a new timezone or default
  /// charity after the settings screen saves. Returns the result so the caller can
  /// surface a failure; on success it notifies listeners. Leaves the cache intact
  /// (and does not flip the phase) when the refresh fails.
  Future<Result<ConfigurationPrincipalRes>> refreshConfig() async {
    final generation = _generation;
    final res = await configs.mine();
    if (generation != _generation) return const Err(Problem.unauthenticated);
    switch (res) {
      case Ok(:final value):
        _config = value.principal;
        notifyListeners();
        return Ok(value.principal);
      case Err(:final problem):
        return Err(problem);
    }
  }

  /// Follow-the-phone: when [followPhoneTimezone] is ON and the device's IANA
  /// timezone differs from Configuration.Timezone, `PUT /Configuration/{id}`
  /// with the phone's timezone (default charity unchanged) and notify. zinc
  /// then re-times pending checks. Returns whether the timezone changed.
  /// Best-effort: a failed PUT leaves the config as is and is retried on the
  /// next launch / resume. Concurrent calls share one in-flight sync.
  Future<bool> syncDeviceTimezone() {
    final running = _timezoneSync;
    if (running != null) return running;
    late final Future<bool> sync;
    sync = _syncDeviceTimezone().whenComplete(() {
      if (identical(_timezoneSync, sync)) _timezoneSync = null;
    });
    return _timezoneSync = sync;
  }

  Future<bool> _syncDeviceTimezone() async {
    final generation = _generation;
    final cfg = _config;
    final id = cfg?.id;
    final charityId = cfg?.defaultCharityId;
    if (cfg == null || id == null || charityId == null || charityId.isEmpty) {
      return false;
    }
    if (!_followPhoneTimezone) return false;
    final device = await deviceTimezone();
    if (generation != _generation) return false;
    if (!shouldSyncTimezone(
      followPhone: _followPhoneTimezone,
      deviceTimezone: device,
      configuredTimezone: cfg.timezone,
    )) {
      return false;
    }
    final res = await configs.update(
      id,
      UpdateConfigurationReq(timezone: device, defaultCharityId: charityId),
    );
    if (generation != _generation) return false;
    if (res case Ok(:final value)) {
      _config = value.principal;
      _timezoneNotice =
          timezoneSettledMessage(device!, value.settledChecks) ??
          _timezoneNotice;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Persists the "Follow phone timezone" preference. Turning it ON
  /// immediately syncs Configuration.Timezone to the phone (see
  /// [syncDeviceTimezone]); turning it OFF keeps the current timezone.
  Future<Result<void>> setFollowPhoneTimezone(bool follow) async {
    try {
      await timezonePreference.saveFollowPhone(follow);
    } catch (e) {
      return Err(
        Problem.local(
          'Could not save the timezone preference',
          type: 'neon:storage',
          detail: '$e',
        ),
      );
    }
    _followPhoneTimezone = follow;
    notifyListeners();
    if (follow) await syncDeviceTimezone();
    return const Ok(null);
  }

  void _fail(Problem problem) {
    _error = problem;
    _setPhase(SessionPhase.error);
  }

  void _setPhase(SessionPhase phase) {
    _phase = phase;
    notifyListeners();
  }
}
