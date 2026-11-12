import 'package:flutter/material.dart';
import '../../widgets/glass_modal.dart';

import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../data/proof_repository.dart';
import '../../data/strava_repository.dart';
import '../../generated/zinc/models/plugin_manifest_res.dart';
import '../../generated/zinc/models/proof_binding_res.dart';
import '../../session/session_controller.dart';
import '../subscription/subscription_view.dart';
import '../subscription/tier.dart';
import 'strava_settings.dart';
import 'strava_view.dart';

/// Habit editor card: complete this habit from Strava. Saves on its own (not
/// with "Save changes"). Hidden where zinc has no Strava (plugin missing or
/// the Strava routes answer 404).
///
/// [StravaProofTile.draft] is for a habit not created yet: the picked sport
/// types go to [onDraftChanged], and the editor binds them after Create.
class StravaProofTile extends StatefulWidget {
  final String? habitId;
  final List<String> draft;
  final ValueChanged<List<String>>? onDraftChanged;

  const StravaProofTile({super.key, required String this.habitId})
    : draft = const [],
      onDraftChanged = null;

  const StravaProofTile.draft({
    super.key,
    required this.draft,
    required ValueChanged<List<String>> this.onDraftChanged,
  }) : habitId = null;

  @override
  State<StravaProofTile> createState() => _StravaProofTileState();
}

enum _Phase { loading, hidden, ready, error }

class _StravaProofTileState extends State<StravaProofTile> {
  late final SessionController _session;
  late final ProofRepository _proof;
  late final StravaRepository _strava;

  _Phase _phase = _Phase.loading;
  Problem? _error;
  PluginManifestRes? _manifest;
  String? _tier;
  bool _connected = false;
  List<String> _bound = const []; // sport types; empty = not on Strava
  bool _saving = false;
  String? _saveError;
  bool _saveErrorIsTier = false;

  @override
  void initState() {
    super.initState();
    _session = context.read<SessionController>();
    final api = _session.auth.makeApiClient();
    _proof = ProofRepository(api);
    _strava = StravaRepository(api);
    _load();
  }

  Future<void> _load() async {
    final uid = _session.userId;
    if (uid == null) return;
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    final pluginsCall = _proof.plugins();
    final statusCall = _strava.status(uid);
    final id = widget.habitId;
    final bindingCall = id == null
        ? Future.value(
            Ok(
              ProofBindingRes(
                habitId: '',
                pluginVersion: 0,
                pluginKey: widget.draft.isEmpty ? null : stravaPluginKey,
                settings: encodeStravaSettings(widget.draft),
              ),
            ),
          )
        : _proof.binding(uid, id);
    final tierCall = _session.subscriptions.current(uid);
    final plugins = await pluginsCall;
    final status = await statusCall;
    final binding = await bindingCall;
    final tier = await tierCall;
    if (!mounted) return;
    setState(() {
      if (tier case Ok(:final value)) _tier = value.tier;
      switch ((plugins, status, binding)) {
        case (Ok(value: final ps), Ok(value: final st), Ok(value: final b)):
          _manifest = ps.where((p) => p.key == stravaPluginKey).firstOrNull;
          _connected = st.connected;
          _bound = b.pluginKey == stravaPluginKey
              ? sportTypesFromSettings(b.settings)
              : const [];
          _phase = _manifest == null ? _Phase.hidden : _Phase.ready;
        case (_, Err(:final problem), _) when problem.status == 404:
          _phase = _Phase.hidden; // Strava is off on this landscape.
        case (Err(:final problem), _, _) ||
            (_, Err(:final problem), _) ||
            (_, _, Err(:final problem)):
          _phase = _Phase.error;
          _error = problem;
      }
    });
  }

  Future<void> _openStrava() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StravaView()));
    if (mounted) _load();
  }

  Future<void> _openPlans() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SubscriptionView()));
    if (mounted) _load();
  }

  Future<void> _pick() async {
    final options = sportTypesFromSchema(_manifest?.settingsSchema);
    final picked = await showGlassSheet<List<String>>(
      context,
      (_) => _SportTypeSheet(options: options, initial: _bound),
    );
    if (picked == null || !mounted) return;
    await _save(picked);
  }

  /// Binds with [sportTypes], or puts the habit back on manual when empty.
  Future<void> _save(List<String> sportTypes) async {
    final uid = _session.userId;
    if (uid == null) return;
    final habitId = widget.habitId;
    if (habitId == null) {
      widget.onDraftChanged!(sportTypes);
      setState(() => _bound = sportTypes);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _saveErrorIsTier = false;
    });
    final Result<Object?> res = sportTypes.isEmpty
        ? await _proof.unbind(uid, habitId)
        : await _proof.bind(
            uid,
            habitId,
            pluginKey: stravaPluginKey,
            settings: encodeStravaSettings(sportTypes),
          );
    if (!mounted) return;
    switch (res) {
      case Ok():
        setState(() {
          _saving = false;
          _bound = sportTypes;
        });
      case Err(:final problem):
        final tier = isTierProblem(problem);
        // A 400 here is almost always "connect Strava first" (the picker
        // only offers allowed sport types), so re-read the connection.
        if (problem.status == 400 && !tier) {
          final st = await _strava.status(uid);
          if (st case Ok(:final value)) _connected = value.connected;
        }
        if (!mounted) return;
        setState(() {
          _saving = false;
          _saveErrorIsTier = tier;
          _saveError = tier
              ? 'Strava proof needs the Pro plan or higher.'
              : problem.status == 400 && !_connected
              ? 'Connect Strava first, then choose it for this habit.'
              : problem.displayMessage;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const leading = Icon(Icons.directions_run_rounded, color: stravaOrange);
    switch (_phase) {
      case _Phase.hidden:
        return const SizedBox.shrink();
      case _Phase.loading:
        return const Glass(
          child: GlassRow(
            leading: leading,
            title: 'Complete with Strava',
            subtitle: 'Loading…',
            trailing: _Spinner(),
          ),
        );
      case _Phase.error:
        return Glass(
          child: GlassRow(
            leading: leading,
            title: 'Complete with Strava',
            subtitle: _error?.displayMessage ?? 'Could not load',
            trailing: GlassTextButton(label: 'Retry', onPressed: _load),
          ),
        );
      case _Phase.ready:
        break;
    }

    final allowed = tierMeets(_tier, _manifest?.minTier);
    final bound = _bound.isNotEmpty;
    final String subtitle;
    final VoidCallback? onTap;
    Widget? trailing;
    if (bound) {
      subtitle =
          'Checks off when you record: '
          '${_bound.map(sportTypeLabel).join(', ')}';
      onTap = _saving ? null : _pick;
      trailing = Semantics(
        button: true,
        label: 'Stop using Strava',
        excludeSemantics: true,
        child: Pressable(
          onTap: _saving ? null : () => _save(const []),
          scale: 0.9,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.close_rounded,
              size: 20,
              color: GlassTokens.of(context).muted,
            ),
          ),
        ),
      );
    } else if (!allowed) {
      subtitle =
          'Part of ${tierLabel(_manifest?.minTier ?? 'pro')} and Ultimate. '
          'Tap to see plans.';
      onTap = _openPlans;
    } else if (!_connected) {
      subtitle = 'Connect Strava to check this habit off from your activities';
      onTap = _openStrava;
    } else {
      subtitle = 'Off. Tap to pick the activities that count.';
      onTap = _saving ? null : _pick;
    }

    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassRow(
            leading: Icon(
              allowed ? Icons.directions_run_rounded : Icons.lock_outline,
              color: stravaOrange,
            ),
            title: 'Complete with Strava',
            subtitle: subtitle,
            trailing: _saving ? const _Spinner() : trailing,
            chevron: trailing == null && !_saving,
            onTap: onTap,
          ),
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 0, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _saveError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  if (_saveErrorIsTier)
                    GlassTextButton(label: 'See plans', onPressed: _openPlans)
                  else if (!_connected)
                    GlassTextButton(label: 'Connect', onPressed: _openStrava),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: GlassTokens.of(context).muted,
    ),
  );
}

/// Multi-select of Strava sport types; pops the picked list (in [options]
/// order), or null when dismissed.
class _SportTypeSheet extends StatefulWidget {
  final List<String> options;
  final List<String> initial;
  const _SportTypeSheet({required this.options, required this.initial});

  @override
  State<_SportTypeSheet> createState() => _SportTypeSheetState();
}

class _SportTypeSheetState extends State<_SportTypeSheet> {
  late final Set<String> _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Activities that count',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'A recorded Strava activity of any of these types, of any '
                'length, completes the habit for the day. You can still check '
                'in by hand.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: GlassTokens.of(context).muted,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: widget.options.isEmpty
                    ? const Text('Could not read Strava’s activity types.')
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final t in widget.options)
                              GlassPill(
                                label: sportTypeLabel(t),
                                on: _picked.contains(t),
                                onTap: () => setState(
                                  () => _picked.contains(t)
                                      ? _picked.remove(t)
                                      : _picked.add(t),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              GlassButton(
                label: 'Use Strava',
                onPressed: _picked.isEmpty
                    ? null
                    : () => Navigator.of(context).pop([
                        for (final t in widget.options)
                          if (_picked.contains(t)) t,
                      ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
