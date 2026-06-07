import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../generated/zinc/models/charity_principal_res.dart';
import '../../session/session_controller.dart';
import '../charity/charity_picker.dart';
import 'timezone_picker.dart';

/// First-run setup (plan §6A): pick a timezone (defaulting to the device's) and a
/// default charity, then `POST /Configuration`. On success the session flips to
/// `ready` and the authed shell shows Home.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  String? _timezone;
  List<String> _timezones = const [];
  CharityPrincipalRes? _charity;

  bool _loading = true;
  bool _submitting = false;
  Problem? _error;

  @override
  void initState() {
    super.initState();
    _loadTimezones();
  }

  Future<void> _loadTimezones() async {
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      final all = await FlutterTimezone.getAvailableTimezones();
      if (!mounted) return;
      setState(() {
        _timezone = local.identifier;
        _timezones = all.map((t) => t.identifier).toList()..sort();
        _loading = false;
      });
    } catch (_) {
      // Fall back to UTC if the platform can't report timezones.
      if (!mounted) return;
      setState(() {
        _timezone = 'UTC';
        _timezones = const ['UTC'];
        _loading = false;
      });
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
    if (picked != null && mounted) setState(() => _charity = picked);
  }

  Future<void> _submit() async {
    final session = context.read<SessionController>();
    final tz = _timezone;
    final charityId = _charity?.id;
    if (tz == null || charityId == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    final res = await session.configs.create(
      timezone: tz,
      defaultCharityId: charityId,
    );
    if (!mounted) return;
    switch (res) {
      case Ok(:final value):
        // Flips the session to `ready`; the authed shell swaps in Home and unmounts us.
        session.onConfigured(value);
      case Err(:final problem):
        setState(() {
          _submitting = false;
          _error = problem;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: AppLoader());
    }
    final theme = Theme.of(context);
    final canSubmit = _timezone != null && _charity?.id != null && !_submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Set up your account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'A few details to get started',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Your timezone sets when each day ends. Your default charity receives '
            'stakes from missed habits — you can change both later.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Timezone'),
              subtitle: Text(_timezone?.replaceAll('_', ' ') ?? 'Not set'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTimezone,
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.volunteer_activism),
              title: const Text('Default charity'),
              subtitle: Text(_charity?.name ?? 'Choose a charity'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickCharity,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!.detail ?? _error!.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canSubmit ? _submit : null,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
