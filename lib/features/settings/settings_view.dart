import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../data/config_repository.dart';
import '../../generated/zinc/models/charity_principal_res.dart';
import '../../generated/zinc/models/configuration_res.dart';
import '../../generated/zinc/models/payment_consent_res.dart';
import '../../generated/zinc/models/update_configuration_req.dart';
import '../../session/session_controller.dart';
import '../../session/timezone_preference.dart';
import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/glass_page.dart';
import '../charity/charity_picker.dart';
import 'timezone_picker.dart';
import '../payment/consent_service.dart';
import '../subscription/subscription_view.dart';

/// The last part of an IANA id, as people say it: `America/New_York` → "New
/// York".
String timezoneCity(String id) => id.split('/').last.replaceAll('_', ' ');

/// Account settings: "Follow phone" and the timezone, the default charity,
/// the payment card and the plan. Loads `GET /Configuration/me` (its `charity`
/// gives the default charity's name) and the payment consent.
///
/// Each change saves as soon as it is made (`PUT /Configuration/{id}`), like
/// the phone's own Settings. Only a hand-picked timezone asks first, because
/// the change can settle days that already ended in the new zone.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  ConfigurationRes? _config;
  PaymentConsentRes? _consent;

  /// The IANA list for the picker.
  List<String> _timezones = const [];

  /// Shown while following the phone and before the config loads.
  String? _timezone;

  bool _followPhone = true;

  bool _loading = true;
  bool _saving = false;
  bool _consentBusy = false;
  bool _timezoneDiscoveryFailed = false;
  Problem? _loadError;

  /// The last failed save or payment action, shown as a banner at the top.
  Problem? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final session = context.read<SessionController>();
    _followPhone = session.followPhoneTimezone;

    await _loadTimezones();

    final cfgRes = await session.configs.mine();
    if (!mounted) return;
    switch (cfgRes) {
      case Ok(:final value):
        _config = value;
        _timezone = value.principal.timezone ?? _timezone;
      case Err(:final problem):
        setState(() {
          _loading = false;
          _loadError = problem;
        });
        return;
    }

    // Consent is informational only; a failure here shouldn't block the screen.
    final userId = session.userId;
    if (userId != null) {
      final consentRes = await session.payments.consent(userId);
      if (!mounted) return;
      if (consentRes case Ok(:final value)) _consent = value;
    }

    setState(() => _loading = false);
  }

  Future<void> _loadTimezones() async {
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      if (!mounted) return;
      _timezone ??=
          context.read<SessionController>().config?.timezone ??
          local.identifier;
      final all = await FlutterTimezone.getAvailableTimezones();
      if (all.isEmpty) throw StateError('No platform timezones');
      if (!mounted) return;
      setState(() {
        _timezones = all.map((t) => t.identifier).toList()..sort();
        _timezoneDiscoveryFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _timezone ??=
            context.read<SessionController>().config?.timezone ?? 'UTC';
        _timezones = bundledTimezones();
        _timezoneDiscoveryFailed = true;
      });
    }
  }

  void _toast(String text, {Duration duration = const Duration(seconds: 4)}) =>
      showGlassToast(context, text, duration: duration);

  /// Saves [timezone] and [charityId] to zinc straight away. Returns the
  /// update, or null after showing the error.
  Future<ConfigurationUpdate?> _put({
    required String timezone,
    required String? charityId,
  }) async {
    final session = context.read<SessionController>();
    final id = _config?.principal.id;
    if (id == null) return null;
    setState(() {
      _saving = true;
      _error = null;
    });
    final res = await session.configs.update(
      id,
      UpdateConfigurationReq(timezone: timezone, defaultCharityId: charityId),
    );
    if (!mounted) return null;
    switch (res) {
      case Ok(:final value):
        // Best-effort: the dashboard and habit defaults read the cached config.
        await session.refreshConfig();
        if (!mounted) return null;
        setState(() => _saving = false);
        return value;
      case Err(:final problem):
        setState(() {
          _saving = false;
          _error = problem;
        });
        return null;
    }
  }

  /// "Follow phone" saves at once. Turning it on also moves the timezone to
  /// the phone's.
  Future<void> _setFollowPhone(bool follow) async {
    final session = context.read<SessionController>();
    setState(() {
      _saving = true;
      _error = null;
    });
    final res = await session.setFollowPhoneTimezone(follow);
    if (!mounted) return;
    setState(() {
      _saving = false;
      switch (res) {
        case Ok():
          _followPhone = follow;
          final principal = session.config;
          final cfg = _config;
          if (follow && principal != null && cfg != null) {
            // The sync PUT may have moved the timezone: rebase on it.
            _config = ConfigurationRes(
              principal: principal,
              charity: cfg.charity,
            );
            _timezone = principal.timezone ?? _timezone;
          }
        case Err(:final problem):
          _error = problem;
      }
    });
    if (res is Ok) {
      _toast(follow ? 'Following your phone’s timezone' : 'Saved');
    }
  }

  /// Picks a timezone by hand, asks first, then saves it.
  Future<void> _pickTimezone() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => TimezonePicker(
          timezones: {..._timezones, ?_timezone}.toList()..sort(),
          selected: _timezone,
        ),
      ),
    );
    if (picked == null || picked == _timezone || !mounted) return;
    final city = timezoneCity(picked);
    final ok = await showGlassConfirm(
      context,
      title: 'Change timezone to $city?',
      message:
          'Each habit day will end at midnight $city time. Days that have '
          'already ended in $city are settled now.',
      confirmLabel: 'Change',
      destructive: false,
    );
    if (!ok || !mounted) return;
    final update = await _put(
      timezone: picked,
      charityId: _config?.principal.defaultCharityId,
    );
    if (update == null || !mounted) return;
    setState(() {
      _timezone = picked;
      _config = ConfigurationRes(
        principal: update.principal,
        charity: _config?.charity,
      );
    });
    final settled = timezoneSettledMessage(picked, update.settledChecks);
    _toast(
      settled ?? 'Timezone changed to $city',
      duration: Duration(seconds: settled == null ? 4 : 8),
    );
  }

  /// Picks the default charity and saves it.
  Future<void> _pickCharity() async {
    final session = context.read<SessionController>();
    final picked = await Navigator.of(context).push<CharityPrincipalRes>(
      MaterialPageRoute(
        builder: (_) => CharityPicker(
          repository: session.charities,
          causeRepository: session.causes,
        ),
      ),
    );
    final tz = _config?.principal.timezone ?? _timezone;
    if (picked == null || tz == null || !mounted) return;
    if (picked.id == _config?.principal.defaultCharityId) return;
    final update = await _put(timezone: tz, charityId: picked.id);
    if (update == null || !mounted) return;
    setState(() {
      _config = ConfigurationRes(principal: update.principal, charity: picked);
    });
    _toast('Default charity saved');
  }

  /// Runs the full consent collection flow (confirm → native sheet → poll).
  Future<void> _setUpConsent() async {
    final session = context.read<SessionController>();
    setState(() {
      _consentBusy = true;
      _error = null;
    });
    final res = await ConsentService(session).ensureConsent(context);
    if (!mounted) return;
    switch (res) {
      case Ok():
        setState(() {
          _consent = session.consent ?? _consent;
          _consentBusy = false;
        });
        _toast('Card added');
      case Err(:final problem):
        setState(() {
          _consentBusy = false;
          _error = problem;
        });
    }
  }

  /// Revokes consent, then re-reads it to confirm.
  Future<void> _removeConsent() async {
    final session = context.read<SessionController>();
    final userId = session.userId;
    if (userId == null) return;

    final ok = await showGlassConfirm(
      context,
      title: 'Remove your card?',
      message:
          'Staked habits stay as they are, but misses can’t be charged until '
          'you add a card again.',
      confirmLabel: 'Remove card',
    );
    if (!ok || !mounted) return;

    setState(() {
      _consentBusy = true;
      _error = null;
    });
    final res = await session.payments.revokeConsent(userId);
    if (!mounted) return;
    if (res case Err(:final problem)) {
      setState(() {
        _consentBusy = false;
        _error = problem;
      });
      return;
    }
    await session.refreshConsent();
    if (!mounted) return;
    setState(() {
      _consent = session.consent ?? _consent;
      _consentBusy = false;
    });
    _toast('Card removed');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AmbientBackdrop(
        child: Scaffold(backgroundColor: Colors.transparent, body: AppLoader()),
      );
    }
    return GlassPage(
      title: 'Settings',
      children: _loadError != null
          ? [
              GlassBanner(
                icon: Icons.error_outline_rounded,
                title: _loadError!.title,
                body: _loadError!.detail,
                error: true,
                action: TextButton(
                  onPressed: _load,
                  child: const Text('Retry'),
                ),
              ),
            ]
          : _content(context),
    );
  }

  List<Widget> _content(BuildContext context) {
    final t = GlassTokens.of(context);
    final cfg = _config;
    final charityId = cfg?.principal.defaultCharityId;
    final hasCharity = charityId?.isNotEmpty ?? false;
    final has = _consent?.hasPaymentConsent ?? false;
    final busy = _saving || _consentBusy;
    final tz = _timezone;
    return [
      if (_error != null)
        GlassBanner(
          icon: Icons.error_outline_rounded,
          title: _error!.displayMessage,
          error: true,
        ),
      if (_timezoneDiscoveryFailed)
        GlassBanner(
          icon: Icons.public_off_rounded,
          title: 'Timezone list unavailable',
          body: timezoneDiscoveryNotice,
          action: TextButton(
            onPressed: _loadTimezones,
            child: const Text('Retry'),
          ),
        ),
      GlassSection(
        title: 'Timezone',
        footer: _followPhone
            ? 'Your timezone moves with your phone when you travel. Each habit '
                  'day ends at midnight in it.'
            : 'Your timezone stays put when you travel. Tap it to pick a '
                  'region.',
        children: [
          GlassRow(
            leading: const Icon(Icons.smartphone_rounded),
            title: 'Follow phone',
            trailing: GlassSwitch(
              value: _followPhone,
              onChanged: busy ? null : _setFollowPhone,
            ),
          ),
          GlassRow(
            leading: const Icon(Icons.public_rounded),
            title: 'Timezone',
            value: tz == null ? 'Not set' : timezoneCity(tz),
            onTap: _followPhone || busy ? null : _pickTimezone,
          ),
        ],
      ),
      GlassSection(
        title: 'Giving',
        children: [
          GlassRow(
            leading: Icon(Icons.favorite_border_rounded, color: t.muted),
            title: hasCharity
                ? cfg?.charity?.name ?? 'Default charity'
                : 'Default charity',
            subtitle: hasCharity
                ? 'Pre-filled when you stake money'
                : 'None yet. Set when you first stake money.',
            value: hasCharity ? null : 'Choose',
            onTap: busy ? null : _pickCharity,
          ),
        ],
      ),
      GlassSection(
        title: 'Payment',
        children: [
          if (_consentBusy)
            const GlassRow(
              leading: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: 'Updating your card…',
            )
          else if (_consent == null)
            const GlassRow(
              leading: Icon(Icons.credit_card_off_outlined),
              title: 'Card status unavailable',
              subtitle: 'Could not load your payment details.',
            )
          else if (has) ...[
            GlassRow(
              leading: Icon(Icons.verified_user_outlined, color: t.accent),
              title: 'Card on file',
              subtitle:
                  'Held by Airwallex. Charged only when you miss a staked day.',
            ),
            GlassRow(
              leading: const Icon(Icons.delete_outline_rounded),
              title: 'Remove card',
              destructive: true,
              chevron: false,
              onTap: busy ? null : _removeConsent,
            ),
          ] else
            GlassRow(
              leading: const Icon(Icons.credit_card_rounded),
              title: 'No card on file',
              subtitle: 'Needed before you stake money.',
              trailing: GlassButton(
                label: 'Add card',
                compact: true,
                onPressed: busy ? null : _setUpConsent,
              ),
            ),
        ],
      ),
      GlassSection(
        title: 'Plan',
        children: [
          GlassRow(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: 'Subscription',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SubscriptionView())),
          ),
        ],
      ),
    ];
  }
}
