import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../generated/zinc/models/charity_principal_res.dart';
import '../../generated/zinc/models/configuration_res.dart';
import '../../generated/zinc/models/payment_consent_res.dart';
import '../../generated/zinc/models/update_configuration_req.dart';
import '../../session/session_controller.dart';
import '../charity/charity_picker.dart';
import '../onboarding/timezone_picker.dart';

/// M5 — account settings (mirrors argon's `settings.tsx` field-card layout, minus
/// the web-only consent SETUP/REMOVAL actions, which land in M6). Loads the user's
/// configuration (`GET /Configuration/me` — its `charity` object gives the default
/// charity's *name*, which the cached principal lacks) and a read-only payment
/// consent status, then lets the user change timezone + default charity and
/// `PUT /Configuration/{id}`.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Loaded baseline (to diff against for the Save button).
  ConfigurationRes? _config;
  PaymentConsentRes? _consent;

  // The IANA list + device default (loaded like onboarding_view.dart).
  List<String> _timezones = const [];

  // Current (possibly edited) selections.
  String? _timezone;
  String? _charityId;
  String? _charityName;

  bool _loading = true;
  bool _saving = false;
  Problem? _loadError;
  Problem? _saveError;

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

    // Timezones first (device default + IANA list), then the config + consent.
    await _loadTimezones();

    final cfgRes = await session.configs.mine();
    if (!mounted) return;
    switch (cfgRes) {
      case Ok(:final value):
        _config = value;
        _timezone = value.principal.timezone ?? _timezone;
        _charityId = value.principal.defaultCharityId;
        _charityName = value.charity.name;
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
      final all = await FlutterTimezone.getAvailableTimezones();
      if (!mounted) return;
      _timezone = local.identifier;
      _timezones = all.map((t) => t.identifier).toList()..sort();
    } catch (_) {
      if (!mounted) return;
      _timezone = 'UTC';
      _timezones = const ['UTC'];
    }
  }

  Future<void> _pickTimezone() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            TimezonePicker(timezones: _timezones, selected: _timezone),
      ),
    );
    if (picked != null && mounted) setState(() => _timezone = picked);
  }

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
    if (picked != null && mounted) {
      setState(() {
        _charityId = picked.id;
        _charityName = picked.name;
      });
    }
  }

  /// Save is enabled only when timezone or defaultCharityId actually changed vs
  /// the loaded config, AND a charity is selected (zinc 422s on a null/empty id).
  bool get _canSave {
    final cfg = _config;
    if (cfg == null) return false;
    final charityId = _charityId;
    if (charityId == null || charityId.isEmpty) return false;
    final changed = _timezone != cfg.principal.timezone ||
        charityId != cfg.principal.defaultCharityId;
    return changed && !_saving;
  }

  Future<void> _save() async {
    final session = context.read<SessionController>();
    final id = _config?.principal.id;
    final tz = _timezone;
    final charityId = _charityId;
    if (id == null || tz == null || charityId == null || charityId.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final res = await session.configs.update(
      id,
      UpdateConfigurationReq(timezone: tz, defaultCharityId: charityId),
    );
    if (!mounted) return;

    switch (res) {
      case Ok():
        // Refresh the cached config so the dashboard / habit defaults pick up
        // the new timezone + charity. Best-effort: a refresh failure doesn't
        // undo the successful save.
        await session.refreshConfig();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
        Navigator.of(context).pop();
      case Err(:final problem):
        setState(() {
          _saving = false;
          _saveError = problem;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorRetry(problem: _loadError!, onRetry: _load)
              : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Manage your account preferences',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        _FieldCard(
          icon: Icons.public,
          label: 'Timezone',
          value: _timezone?.replaceAll('_', ' ') ?? 'Not set',
          subtitle:
              'Sets when each day ends and when habit reminders fire. Pick the '
              'region closest to you.',
          onTap: _pickTimezone,
        ),
        _FieldCard(
          icon: Icons.volunteer_activism,
          label: 'Default charity',
          value: _charityName ?? 'Choose a charity',
          subtitle:
              'The charity pre-selected when you create a habit. You can change '
              'this anytime.',
          onTap: _pickCharity,
        ),
        _ConsentCard(consent: _consent),
        if (_saveError != null) ...[
          const SizedBox(height: 12),
          Text(
            _saveError!.detail ?? _saveError!.title,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save changes'),
        ),
      ],
    );
  }
}

/// A tappable field card (mirrors argon's FieldCard): label + current value +
/// subtitle/restriction line, with a chevron affordance.
class _FieldCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final VoidCallback onTap;
  const _FieldCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurface)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Read-only payment-consent status (M5). The SETUP / REMOVE actions are M6.
class _ConsentCard extends StatelessWidget {
  final PaymentConsentRes? consent;
  const _ConsentCard({required this.consent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = consent;
    final has = c?.hasPaymentConsent ?? false;
    final String detail;
    if (c == null) {
      detail = 'Could not load payment consent status.';
    } else if (has) {
      final status = c.status;
      detail = status == null || status.isEmpty
          ? 'Payment consent is active.'
          : 'Payment consent is active ($status).';
    } else {
      detail = 'No payment consent on file. Set it up to enable stakes and '
          'donations.';
    }
    return Card(
      child: ListTile(
        leading: Icon(
          has ? Icons.verified_user : Icons.gpp_maybe,
          color: has ? Colors.green.shade700 : theme.colorScheme.outline,
        ),
        title: const Text('Payment consent'),
        subtitle: Text(detail),
        isThreeLine: false,
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final Problem problem;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.problem, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(problem.title, style: Theme.of(context).textTheme.titleMedium),
            if (problem.detail != null) ...[
              const SizedBox(height: 8),
              Text(problem.detail!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
