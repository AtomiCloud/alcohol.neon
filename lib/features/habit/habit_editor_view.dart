import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../generated/zinc/models/charity_principal_res.dart';
import '../../generated/zinc/models/create_habit_req.dart';
import '../../generated/zinc/models/update_habit_req.dart';
import '../../session/session_controller.dart';
import '../../theme/app_theme.dart';
import '../charity/charity_picker.dart';
import '../nfc/link_tag_flow.dart';
import '../payment/consent_service.dart';
import 'stake_sheet.dart';

/// M3 — create / edit a habit. Field contract mirrors argon (verified against
/// zinc's HabitValidator): day names are PascalCase (e.g. "Monday"),
/// notificationTime is "HH:mm:ss", stake is a non-negative decimal string ("0"
/// when none), timezone comes from the user's configuration. On save it pops
/// `true` so the dashboard refreshes.
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
        _days
          ..clear()
          ..addAll(h.daysOfWeek ?? const []);
        _charityId = h.charityId;
        _loadCharityName(h.charityId);
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
    if (_charityId == null) return 'Choose a charity';
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
    final tz = _session.config?.timezone ?? 'UTC';
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
    final stakeAmount = double.tryParse(_stakeWire) ?? 0;
    if (stakeAmount > 0 && !_session.hasPaymentConsent) {
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
          charityId: _charityId!,
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
          charityId: _charityId!,
          timezone: tz,
        ),
      );
    }

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
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.volunteer_activism),
                    title: const Text('Charity'),
                    subtitle: Text(_charityName ?? 'Choose a charity'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickCharity,
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
