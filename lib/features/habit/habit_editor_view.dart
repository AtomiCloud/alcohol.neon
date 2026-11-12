import 'package:flutter/cupertino.dart';
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
import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/glass_page.dart';
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

  /// A wheel in a sheet on iOS, the Material time picker on Android.
  Future<void> _pickTime() async {
    if (!isCupertino(context)) {
      final picked = await showTimePicker(context: context, initialTime: _time);
      if (picked != null && mounted) setState(() => _time = picked);
      return;
    }
    var picked = _time;
    final done = await showGlassSheet<bool>(
      context,
      (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Remind me at',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: MediaQuery.alwaysUse24HourFormatOf(ctx),
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    _time.hour,
                    _time.minute,
                  ),
                  onDateTimeChanged: (d) =>
                      picked = TimeOfDay(hour: d.hour, minute: d.minute),
                ),
              ),
              GlassButton(
                label: 'Done',
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (done == true && mounted) setState(() => _time = picked);
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
    showGlassToast(
      context,
      '“$name” is created, but ${failed.join(' and ')} isn’t set up. '
      'Try again here.',
      duration: const Duration(seconds: 8),
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
    final scan = await showGlassSheet<bool>(context, (ctx) {
      final t = GlassTokens.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nfc_rounded, size: 48, color: t.accent),
              const SizedBox(height: 12),
              Text(
                'Link an NFC tag to “$name”',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the sticker any day to complete the habit.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.muted),
              ),
              const SizedBox(height: 20),
              GlassButton(
                label: 'Scan tag',
                onPressed: () => Navigator.pop(ctx, true),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: t.muted),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      );
    });
    return scan ?? false;
  }

  Future<void> _delete() async {
    final uid = _session.userId;
    if (uid == null) return;
    final name = _task.text.trim();
    final confirmed = await showGlassConfirm(
      context,
      title: 'Delete habit?',
      message:
          'This removes ${name.isEmpty ? 'the habit' : name} and its history. '
          'It can’t be undone.',
      confirmLabel: 'Delete habit',
    );
    if (!confirmed || !mounted) return;
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

  /// "Weekdays · reminder at 22:00 · nothing at stake", under the name.
  String _summary(BuildContext context) {
    const weekdays = {'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'};
    final String days;
    if (_days.length == 7) {
      days = 'Every day';
    } else if (_days.length == 5 && _days.containsAll(weekdays)) {
      days = 'Weekdays';
    } else if (_days.length == 2 && _days.containsAll({'Saturday', 'Sunday'})) {
      days = 'Weekends';
    } else if (_days.isEmpty) {
      days = 'No days yet';
    } else {
      days = [
        for (final (key, label) in _weekDays)
          if (_days.contains(key)) label,
      ].join(', ');
    }
    final stake = !_staked
        ? 'nothing at stake'
        : '${_stakeDisplay()} to ${_charityName ?? 'a charity you choose'} '
              'if you miss';
    return '$days · reminder at ${_time.format(context)} · $stake';
  }

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final session = context.watch<SessionController>();
    final hasDefaultCharity =
        session.config?.defaultCharityId?.isNotEmpty ?? false;
    final charityHint = !_staked
        ? 'No money at stake, so no charity needed. Add a stake any time.'
        : hasDefaultCharity
        ? null
        : 'A charity is only needed because there’s money at stake. Your '
              'first one is remembered for next time.';
    final title = widget.isEdit ? 'Edit habit' : 'New habit';
    if (_loading) {
      return GlassPage(
        title: title,
        modal: !widget.isEdit,
        children: const [SizedBox(height: 240, child: AppLoader())],
      );
    }
    final name = _task.text.trim().isEmpty ? 'this habit' : _task.text.trim();
    return GlassPage(
      title: title,
      modal: !widget.isEdit,
      dock: GlassButton(
        label: widget.isEdit ? 'Save changes' : 'Create habit',
        busy: _saving,
        onPressed: _save,
      ),
      children: [
        if (_error != null)
          GlassBanner(
            icon: Icons.error_outline_rounded,
            title: _friendly(_error!),
            error: true,
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Glass(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _task,
                  maxLength: 256,
                  autofocus: !widget.isEdit,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Name your habit',
                    hintStyle: TextStyle(color: t.muted),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _summary(context),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
        ),
        const GlassHeading('Days'),
        Glass(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (key, label) in _weekDays)
                _DayToggle(
                  label: label,
                  on: _days.contains(key),
                  onTap: () => setState(
                    () => _days.contains(key)
                        ? _days.remove(key)
                        : _days.add(key),
                  ),
                ),
            ],
          ),
        ),
        GlassSection(
          title: 'Reminder',
          children: [
            GlassRow(
              leading: const Icon(Icons.notifications_none_rounded),
              title: 'Remind me at',
              value: _time.format(context),
              onTap: _pickTime,
            ),
          ],
        ),
        GlassSection(
          title: 'If you miss',
          footer: charityHint,
          children: [
            GlassRow(
              leading: Icon(Icons.attach_money_rounded, color: t.accent),
              title: 'Stake',
              value: _staked ? _stakeDisplay() : 'None',
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
            if (_staked)
              // Only the charity's name, on one line, so long names fit.
              GlassRow(
                leading: const Icon(Icons.volunteer_activism),
                title: _charityName ?? 'Choose a charity',
                accent: _charityName == null,
                onTap: _pickCharity,
              ),
          ],
        ),
        const GlassHeading('Proof'),
        if (widget.isEdit) ...[
          StravaProofTile(habitId: widget.habitId!),
          const SizedBox(height: 8),
          Glass(
            child: GlassRow(
              leading: const Icon(Icons.nfc_rounded),
              title: 'Link NFC tag',
              subtitle: 'Tap a sticker to complete this habit',
              onTap: () => runLinkTagFlow(
                context,
                habitId: widget.habitId!,
                habitName: name,
              ),
            ),
          ),
          const GlassFooter('Proof saves as soon as you change it.'),
          // Friends need the habit id and save on their own.
          const GlassHeading('Friends'),
          FriendStakeTile(habitId: widget.habitId!),
          GlassSection(
            title: 'Status',
            children: [
              GlassRow(
                leading: const Icon(Icons.pause_rounded),
                title: 'Pause this habit',
                subtitle: 'No checks or charges while paused',
                trailing: GlassSwitch(
                  value: !_enabled,
                  onChanged: (v) => setState(() => _enabled = !v),
                ),
              ),
            ],
          ),
          GlassSection(
            children: [
              GlassRow(
                title: 'Delete habit',
                destructive: true,
                centered: true,
                chevron: false,
                onTap: _saving ? null : _delete,
              ),
            ],
          ),
        ] else ...[
          StravaProofTile.draft(
            draft: _stravaDraft,
            onDraftChanged: (v) => setState(() => _stravaDraft = v),
          ),
          const SizedBox(height: 8),
          Glass(
            child: GlassRow(
              leading: const Icon(Icons.nfc_rounded),
              title: 'NFC tag',
              subtitle: _nfcDraft ? 'Scan it after Create' : 'Tap a sticker',
              trailing: GlassSwitch(
                value: _nfcDraft,
                onChanged: (v) => setState(() => _nfcDraft = v),
              ),
              onTap: () => setState(() => _nfcDraft = !_nfcDraft),
            ),
          ),
          const GlassFooter(
            'Optional. Leave both off and you tick it off yourself. '
            'Friends can be told once the habit exists.',
          ),
        ],
      ],
    );
  }
}

/// One round day toggle in the Days row.
class _DayToggle extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _DayToggle({
    required this.label,
    required this.on,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.9,
        child: AnimatedContainer(
          duration: GlassMotion.of(context, GlassMotion.fast),
          curve: GlassMotion.curve,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? t.accent : Colors.transparent,
            border: on ? null : Border.all(color: t.separator, width: 1),
          ),
          child: Text(
            label.substring(0, 1),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: on ? t.onAccent : t.muted,
            ),
          ),
        ),
      ),
    );
  }
}
