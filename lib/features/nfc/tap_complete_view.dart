import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../data/nfc_tag_repository.dart';
import '../../session/session_controller.dart';

/// Landing screen for a tag tap (plan Flow 2): resolve the tag, then either
/// complete the habit or explain today's state. Repeat taps are idempotent —
/// "already done" is a friendly state, never an error.
class TapCompleteView extends StatefulWidget {
  final String tagId;
  const TapCompleteView({super.key, required this.tagId});

  @override
  State<TapCompleteView> createState() => _TapCompleteViewState();
}

enum _Phase { working, done, alreadyDone, notScheduled, otherStatus, error }

class _TapCompleteViewState extends State<TapCompleteView> {
  _Phase _phase = _Phase.working;
  String? _habitName;
  String? _statusLabel;
  Problem? _problem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    setState(() {
      _phase = _Phase.working;
      _problem = null;
    });

    final session = context.read<SessionController>();
    final uid = session.userId;
    if (uid == null) return; // authed shell guarantees this in practice

    final resolved = await session.nfcTags.resolve(uid, widget.tagId);
    if (!mounted) return;

    final NfcTagResolutionRes resolution;
    switch (resolved) {
      case Ok(:final value):
        resolution = value;
      case Err(:final problem):
        setState(() {
          _phase = _Phase.error;
          _problem = problem.status == 404
              ? Problem.local(
                  'Unknown tag',
                  status: 404,
                  type: 'neon:nfc',
                  detail:
                      "This tag isn't linked to any of your habits. "
                      'Link it from a habit, or scan it from Dashboard → NFC tags.',
                )
              : problem;
        });
        return;
    }

    final version = resolution.habitVersion;
    setState(() => _habitName = version.task);

    // Something already happened today → report it, don't double-act.
    final today = resolution.todayExecution;
    if (today != null) {
      setState(() {
        switch (today.status) {
          case 'succeeded':
            _phase = _Phase.alreadyDone;
          case 'skip':
            _phase = _Phase.otherStatus;
            _statusLabel = 'Skipped today — no action needed.';
          case 'vacation':
            _phase = _Phase.otherStatus;
            _statusLabel = "You're on vacation — the habit is paused.";
          case 'frozen':
            _phase = _Phase.otherStatus;
            _statusLabel = 'A freeze already covered today.';
          default:
            _phase = _Phase.otherStatus;
            _statusLabel = 'Today is already settled (${today.status}).';
        }
      });
      return;
    }

    // Not on today's schedule → friendly status instead of a rogue completion.
    final weekday = _weekdayName(DateTime.now().weekday);
    final days = version.daysOfWeek ?? const [];
    final scheduledToday = days.any((d) => d.toLowerCase() == weekday);
    if (!scheduledToday) {
      setState(() => _phase = _Phase.notScheduled);
      return;
    }

    final completed = await session.executions.complete(uid, version.id);
    if (!mounted) return;
    switch (completed) {
      case Ok():
        setState(() => _phase = _Phase.done);
      case Err(:final problem):
        // A racing double-tap can land here (409/conflict) — treat as done.
        if (problem.status == 409) {
          setState(() => _phase = _Phase.alreadyDone);
        } else {
          setState(() {
            _phase = _Phase.error;
            _problem = problem;
          });
        }
    }
  }

  static String _weekdayName(int weekday) => const [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ][weekday - 1];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = _habitName ?? 'your habit';

    final (
      IconData icon,
      Color? color,
      String title,
      String? body,
    ) = switch (_phase) {
      _Phase.working => (Icons.nfc, null, 'Checking your tag…', null),
      _Phase.done => (
        Icons.check_circle,
        Colors.green,
        'Done!',
        '"$name" is completed for today. See you tomorrow 👋',
      ),
      _Phase.alreadyDone => (
        Icons.thumb_up,
        Colors.green,
        'Already done today',
        '"$name" was already completed — nothing more to do.',
      ),
      _Phase.notScheduled => (
        Icons.event_available,
        null,
        'Rest day',
        '"$name" isn\'t scheduled today. Enjoy the break!',
      ),
      _Phase.otherStatus => (
        Icons.info_outline,
        null,
        'Nothing to do',
        _statusLabel,
      ),
      _Phase.error => (
        Icons.error_outline,
        theme.colorScheme.error,
        _problem?.title ?? 'Something went wrong',
        _problem?.detail,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('NFC tag')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_phase == _Phase.working)
                const CircularProgressIndicator()
              else
                Icon(icon, size: 64, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(body, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              if (_phase == _Phase.error)
                FilledButton(onPressed: _run, child: const Text('Try again'))
              else if (_phase != _Phase.working)
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to dashboard'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
