import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../data/proof_repository.dart';
import '../../generated/zinc/models/charity_principal_res.dart';
import '../../generated/zinc/models/create_habit_req.dart';
import '../../generated/zinc/models/habit_version_res.dart';
import '../../generated/zinc/models/update_habit_req.dart';
import '../../session/session_controller.dart';
import '../../theme/app_theme.dart';
import '../charity/charity_picker.dart';
import '../friends/friend_stake_tile.dart';
import '../nfc/link_tag_flow.dart';
import '../payment/consent_service.dart';
import '../strava/strava_proof_tile.dart';
import '../strava/strava_settings.dart';
import 'stake_sheet.dart';

/// M3 — create / edit a habit. Field contract mirrors argon (verified against
/// zinc's HabitValidator): day names are PascalCase (e.g. "Monday"),
/// notificationTime is "HH:mm:ss", stake is a non-negative decimal string ("0"
/// when none), timezone comes from the user's configuration. A charity is only
/// asked for (and sent) when the stake is above 0. On save it pops `true` so
/// the dashboard refreshes.
class HabitEditorView extends StatefulWidget {
  /// Null → create. Non-null → edit (prefilled from `GET /Habit/{userId}/{id}`).
  final String? habitId;

  /// Edit only: the habit's current enabled state (UpdateHabitReq requires it;
  /// HabitVersionRes doesn't carry it, so the dashboard supplies it).
  final bool initialEnabled;

  const HabitEditorView({super.key, this.habitId, this.initialEnabled = true});

  bool get isEdit => habitId != null;

  @override
  State<HabitEditorView> createState() => _HabitEditorViewState();
}

/// (key sent to zinc, short label). Day names must be PascalCase — zinc's
/// UpdateHabitReq validator parses them case-sensitively.
const _weekDays = <(String, String)>[
  ('Monday', 'Mon'),
  ('Tuesday', 'Tue'),
  ('Wednesday', 'Wed'),
  ('Thursday', 'Thu'),
  ('Friday', 'Fri'),
  ('Saturday', 'Sat'),
  ('Sunday', 'Sun'),
];

class _HabitEditorViewState extends State<HabitEditorView> {
  final _task = TextEditingController();
  final _stake = TextEditingController(text: '0');
  final _days = <String>{
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  };
  TimeOfDay _time = const TimeOfDay(hour: 22, minute: 0);
  String? _charityId;
  String? _charityName;
  String? _existingTimezone;

  // New habit only: proof chosen before Create, set up once the habit exists.
  List<String> _stravaDraft = const [];
  bool _nfcDraft = false;

  bool _enabled = true;
  bool _loading = false; // loading an existing habit (edit)
  bool _saving = false;
  Problem? _error;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
    if (widget.isEdit) {
      _loadExisting();
    } else {
      _prefillDefaultCharity();
    }
  }

  @override
  void dispose() {
    _task.dispose();
    _stake.dispose();
    super.dispose();
  }

  SessionController get _session => context.read<SessionController>();

  Future<void> _loadExisting() async {
    final uid = _session.userId;
    if (uid == null) return;
    setState(() => _loading = true);
    final res = await _session.habits.byId(uid, widget.habitId!);
    if (!mounted) return;
    switch (res) {
      case Ok(:final value):
        // HabitVersionRes is flat (no `principal` wrapper, unlike Charity/User).
        final h = value;
        _task.text = h.task ?? '';
        _stake.text = h.stake ?? '0';
        _time = _parseTime(h.notificationTime) ?? _time;
        _existingTimezone = h.timezone;
        _days
          ..clear()
          ..addAll(h.daysOfWeek ?? const []);
        // A habit with no charity (no stake) gets the default charity, like
        // a new one, in case a stake is added.
        if (h.charityId?.isNotEmpty ?? false) {
          _charityId = h.charityId;
          _loadCharityName(h.charityId);
        } else {
          _prefillDefaultCharity();
        }
      case Err(:final problem):
        _error = problem;
    }
    setState(() => _loading = false);
  }

  Future<void> _prefillDefaultCharity() async {
    final id = _session.config?.defaultCharityId;
    if (id == null || id.isEmpty) return;
    _charityId = id;
    _loadCharityName(id);
  }

  Future<void> _loadCharityName(String? id) async {
    if (id == null || id.isEmpty) return;
    final res = await _session.charities.byId(id);
    if (!mounted) return;
    if (res case Ok(:final value)) {
      setState(() => _charityName = value.principal.name);
    }
  }

  static TimeOfDay? _parseTime(String? hhmmss) {
    if (hhmmss == null) return null;
    final parts = hhmmss.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String get _timeWire =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00';

  String _stakeDisplay() {
    final v = double.tryParse(_stake.text.trim()) ?? 0;
    return v <= 0 ? 'No stake' : 'USD ${v.toStringAsFixed(2)}';
  }

  String get _stakeWire {
    final t = _stake.text.trim();
    return t.isEmpty ? '0' : t;
  }

  bool get _staked => (double.tryParse(_stakeWire) ?? 0) > 0;

  bool get _hasCharity => _charityId?.isNotEmpty ?? false;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null && mounted) setState(() => _time = picked);
  }

  Future<void> _pickCharity() async {
    final picked = await Navigator.of(context).push<CharityPrincipalRes>(
      MaterialPageRoute(
        builder: (_) => CharityPicker(
          repository: _session.charities,
          causeRepository: _session.causes,
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

  /// Friendly message for save failures, mirroring the vacation view's mapping.
  /// zinc's TierInsufficient (RFC7807 type ending in `/v1/tier_insufficient`,
  /// title "Tier Insufficient") historically arrived with an EMPTY detail, so
  /// match it explicitly and explain that the plan's habit limit was hit instead
  /// of leaking a blank or raw server string. (Upgrade CTA sheet: 86ey77mr6.)
  String _friendly(Problem p) {
    final type = p.type.toLowerCase();
    final title = p.title.toLowerCase();
    if (type.contains('tier_insufficient') ||
        (title.contains('tier') && title.contains('insufficient'))) {
      return 'You’ve reached your plan’s habit limit. '
          'Remove a habit or upgrade your plan to add more.';
    }
    return p.displayMessage;
  }

  String? _validate() {
    if (_task.text.trim().isEmpty) return 'Give the habit a name';
    if (_days.isEmpty) return 'Choose at least one day';
    if (_staked && !_hasCharity) return 'Choose a charity';
    if (double.tryParse(_stakeWire) == null) return 'Stake must be a number';
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = Problem.local(problem));
      return;
    }
    final uid = _session.userId;
    if (uid == null) return;
    // Account settings are defaults for new habits, not a timezone migration.
    final tz = widget.isEdit
        ? _existingTimezone
        : _session.config?.timezone ?? 'UTC';
    if (tz == null || tz.isEmpty) {
      setState(() => _error = Problem.local('Reload the habit before saving.'));
      return;
    }
    // zinc validates DaysOfWeek case-sensitively on update — keep canonical order.
    final days = [
      for (final (key, _) in _weekDays)
        if (_days.contains(key)) key,
    ];

    setState(() {
      _saving = true;
      _error = null;
    });

    // Gate staked habits on payment consent. A positive stake needs a card on
    // file, so collect consent first; only proceed if it succeeds. Truth is the
    // session's cached `/consent` GET, never the Logto claim.
    if (_staked && !_session.hasPaymentConsent) {
      final consent = await ConsentService(_session).ensureConsent(context);
      if (!mounted) return;
      if (consent case Err(:final problem)) {
        setState(() {
          _saving = false;
          _error = problem;
        });
        return;
      }
    }

    // With nothing at stake there is no charity to pay, so none is saved.
    final charityId = _staked ? _charityId : null;
    final Result<dynamic> res;
    if (widget.isEdit) {
      res = await _session.habits.update(
        uid,
        widget.habitId!,
        UpdateHabitReq(
          task: _task.text.trim(),
          daysOfWeek: days,
          notificationTime: _timeWire,
          stake: _stakeWire,
          charityId: charityId,
          enabled: _enabled,
          timezone: tz,
        ),
      );
    } else {
      res = await _session.habits.create(
        uid,
        CreateHabitReq(
          task: _task.text.trim(),
          daysOfWeek: days,
          notificationTime: _timeWire,
          stake: _stakeWire,
          charityId: charityId,
          timezone: tz,
        ),
      );
    }

    if (!mounted) return;
    switch (res) {
      case Ok(:final value):
        if (charityId != null) await _session.rememberFirstCharity(charityId);
        if (!mounted) return;
        if (!widget.isEdit && value is HabitVersionRes) {
          return _setUpProof(uid, value.habitId);
        }
        Navigator.of(context).pop(true);
      case Err(:final problem):
        setState(() {
          _saving = false;
          _error = problem;
        });
    }
  }

  /// After Create: binds the Strava proof and links an NFC tag if they were
  /// switched on. The habit already exists, so a failure doesn't undo it:
  /// the editor reopens on the new habit, saying what wasn't set up, where
  /// Strava and NFC can be tried again.
  Future<void> _setUpProof(String uid, String habitId) async {
    final name = _task.text.trim();
    final failed = <String>[];
    if (_stravaDraft.isNotEmpty) {
      final bound = await ProofRepository(_session.auth.makeApiClient()).bind(
        uid,
        habitId,
        pluginKey: stravaPluginKey,
        settings: encodeStravaSettings(_stravaDraft),
      );
      if (!mounted) return;
      if (bound case Err()) failed.add('Strava');
    }
    if (_nfcDraft) {
      final scan = await _askToScan(name);
      if (!mounted) return;
      if (scan &&
          !await runLinkTagFlow(context, habitId: habitId, habitName: name)) {
        failed.add('the NFC tag');
      }
      if (!mounted) return;
    }
    final navigator = Navigator.of(context);
    if (failed.isEmpty) {
      navigator.pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '“$name” is created, but ${failed.join(' and ')} isn’t set up. '
          'Try again here.',
        ),
        duration: const Duration(seconds: 8),
      ),
    );
    navigator.pushReplacement(
      MaterialPageRoute<bool>(
        builder: (_) => HabitEditorView(habitId: habitId),
      ),
      result: true,
    );
  }

  /// Asks to scan the NFC tag now; false when the user picks "Not now".
  Future<bool> _askToScan(String name) async {
    final scan = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.nfc, size: 48),
              const SizedBox(height: 12),
              Text(
                'Link an NFC tag to “$name”',
                style: Theme.of(ctx).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the sticker any day to complete the habit.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Scan tag'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
    return scan ?? false;
  }

  Future<void> _delete() async {
    final uid = _session.userId;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit?'),
        content: const Text('This removes the habit. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    final res = await _session.habits.remove(uid, widget.habitId!);
    if (!mounted) return;
    switch (res) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final problem):
        setState(() {
          _saving = false;
          _error = problem;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<SessionController>();
    final hasDefaultCharity =
        session.config?.defaultCharityId?.isNotEmpty ?? false;
    final charityHint = !_staked
        ? 'No money at stake, so no charity needed. Add a stake any time.'
        : hasDefaultCharity
        ? null
        : 'A charity is only needed because there’s money at stake. Your '
              'first one is remembered for next time.';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit habit' : 'New habit'),
        actions: [
          if (widget.isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: _loading
          ? const AppLoader()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _task,
                  maxLength: 256,
                  decoration: const InputDecoration(
                    labelText: 'Habit',
                    hintText: 'e.g. Morning run',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Days', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (key, label) in _weekDays)
                      FilterChip(
                        label: Text(label),
                        selected: _days.contains(key),
                        onSelected: (on) => setState(
                          () => on ? _days.add(key) : _days.remove(key),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Reminder time'),
                    subtitle: Text(_time.format(context)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickTime,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.attach_money,
                      color: AppColors.money,
                    ),
                    title: const Text('Stake'),
                    subtitle: Text(_stakeDisplay()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final picked = await showStakeSheet(
                        context,
                        initial: _stake.text,
                      );
                      if (picked != null && mounted) {
                        setState(() => _stake.text = picked);
                      }
                    },
                  ),
                ),
                if (_staked) ...[
                  const SizedBox(height: 8),
                  // Only the charity's name, on one line, so long names fit.
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.volunteer_activism),
                      title: Text(
                        _charityName ?? 'Choose a charity',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickCharity,
                    ),
                  ),
                ],
                if (charityHint != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      charityHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (!widget.isEdit) ...[
                  const SizedBox(height: 16),
                  Text('Proof', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  StravaProofTile.draft(
                    draft: _stravaDraft,
                    onDraftChanged: (v) => setState(() => _stravaDraft = v),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.nfc),
                      title: const Text('NFC tag'),
                      subtitle: Text(
                        _nfcDraft ? 'Scan it after Create' : 'Tap a sticker',
                      ),
                      value: _nfcDraft,
                      onChanged: (v) => setState(() => _nfcDraft = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Text(
                      'Optional. Leave both off and you tick it off yourself. '
                      'Friends can be told once the habit exists.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (widget.isEdit) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Enabled'),
                    subtitle: const Text('Pause without deleting'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.nfc),
                      title: const Text('Link NFC tag'),
                      subtitle: const Text(
                        'Tap a sticker to complete this habit',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => runLinkTagFlow(
                        context,
                        habitId: widget.habitId!,
                        habitName: _task.text.trim().isEmpty
                            ? 'this habit'
                            : _task.text.trim(),
                      ),
                    ),
                  ),
                  // Strava proof and friend stake need the habit id and save
                  // on their own, so they're offered once the habit exists.
                  const SizedBox(height: 8),
                  StravaProofTile(habitId: widget.habitId!),
                  FriendStakeTile(habitId: widget.habitId!),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _friendly(_error!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isEdit ? 'Save changes' : 'Create habit'),
                ),
              ],
            ),
    );
  }
}
