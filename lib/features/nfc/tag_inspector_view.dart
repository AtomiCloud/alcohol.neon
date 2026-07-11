import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../core/problem.dart';
import '../../data/nfc_tag_repository.dart';
import '../../session/session_controller.dart';
import 'nfc_service.dart';
import 'tap_complete_view.dart';

/// "What is this tag?" — scans a tag in the foreground (which suppresses the
/// OS deep-link path, so inspecting never accidentally completes anything) and
/// shows what it's linked to: one of your habits (with actions), someone
/// else's, or nothing yet.
class TagInspectorView extends StatefulWidget {
  const TagInspectorView({super.key});

  @override
  State<TagInspectorView> createState() => _TagInspectorViewState();
}

enum _Phase { idle, scanning, yours, notYours, blank, unusable, error }

class _TagInspectorViewState extends State<TagInspectorView> {
  _Phase _phase = _Phase.idle;
  String? _tagId;
  NfcTagResolutionRes? _resolution;
  Problem? _problem;
  bool _acting = false;

  Future<void> _scan() async {
    setState(() {
      _phase = _Phase.scanning;
      _tagId = null;
      _resolution = null;
      _problem = null;
    });

    final session = context.read<SessionController>();
    final uid = session.userId;
    final result = await NfcService().scan(
      base: AppConfig.current.nfcTagBaseUrl,
    );
    if (!mounted) return;

    final NfcScanResult scan;
    switch (result) {
      case Ok(:final value):
        scan = value;
      case Err(:final problem):
        setState(() {
          _phase = _Phase.error;
          _problem = problem;
        });
        return;
    }

    switch (scan.kind) {
      case NfcTagKind.blank:
      case NfcTagKind.foreignWritable:
        setState(() => _phase = _Phase.blank);
        return;
      case NfcTagKind.unusable:
        setState(() => _phase = _Phase.unusable);
        return;
      case NfcTagKind.lazytax:
        break;
    }

    final tagId = scan.tagId;
    if (tagId == null || uid == null) {
      // Never strand the page in "scanning" with a disabled button.
      setState(() {
        _phase = _Phase.error;
        _problem = Problem.local('Scan failed', type: 'neon:nfc');
      });
      return;
    }
    setState(() => _tagId = tagId);

    final resolved = await session.nfcTags.resolve(uid, tagId);
    if (!mounted) return;
    switch (resolved) {
      case Ok(:final value):
        setState(() {
          _resolution = value;
          _phase = _Phase.yours;
        });
      case Err(:final problem):
        if (problem.status == 404) {
          // Unclaimed — or claimed by another account; the server deliberately
          // doesn't distinguish (no ownership leak).
          setState(() => _phase = _Phase.notYours);
        } else {
          setState(() {
            _phase = _Phase.error;
            _problem = problem;
          });
        }
    }
  }

  Future<void> _unlink() async {
    final session = context.read<SessionController>();
    final uid = session.userId;
    final tagId = _tagId;
    if (uid == null || tagId == null || _acting) return;

    setState(() => _acting = true);
    final res = await session.nfcTags.unlink(uid, tagId);
    if (!mounted) return;
    setState(() => _acting = false);
    switch (res) {
      case Ok():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tag unlinked — it can be reused.')),
        );
        setState(() => _phase = _Phase.notYours);
      case Err(:final problem):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(problem.title)));
    }
  }

  Future<void> _complete() async {
    final tagId = _tagId;
    if (tagId == null) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TapCompleteView(tagId: tagId)));
    if (!mounted) return;
    // Re-resolve so the card reflects the completion instead of still
    // offering "Complete now".
    await _refreshResolution();
  }

  Future<void> _refreshResolution() async {
    final session = context.read<SessionController>();
    final uid = session.userId;
    final tagId = _tagId;
    if (uid == null || tagId == null) return;
    final resolved = await session.nfcTags.resolve(uid, tagId);
    if (!mounted) return;
    if (resolved case Ok(:final value)) {
      setState(() => _resolution = value);
    }
    // A failed refresh keeps the previous card — the action itself succeeded.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('NFC tags')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Scan a tag to see which habit it completes. '
            'Scanning here never completes the habit.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _phase == _Phase.scanning ? null : _scan,
            icon: const Icon(Icons.nfc),
            label: Text(_phase == _Phase.scanning ? 'Scanning…' : 'Scan a tag'),
          ),
          const SizedBox(height: 24),
          ..._result(theme),
        ],
      ),
    );
  }

  List<Widget> _result(ThemeData theme) {
    switch (_phase) {
      case _Phase.idle:
        return const [];
      case _Phase.scanning:
        return const [Center(child: CircularProgressIndicator())];
      case _Phase.yours:
        final r = _resolution!;
        final today = r.todayExecution;
        final subtitle = today == null
            ? 'Not completed today yet'
            : switch (today.status) {
                'succeeded' => 'Completed today ✅',
                'skip' => 'Skipped today',
                'vacation' => 'On vacation',
                'frozen' => 'Covered by a freeze today',
                _ => 'Today: ${today.status}',
              };
        return [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🏷 This tag completes',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.habitVersion.task ?? 'Habit',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (today == null)
                        FilledButton(
                          onPressed: _complete,
                          child: const Text('Complete now'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: _acting ? null : _unlink,
                        child: const Text('Unlink'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'To point this tag at a different habit, open that habit and '
            'choose "Link NFC tag".',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ];
      case _Phase.notYours:
        return [
          _info(
            theme,
            Icons.help_outline,
            'Not linked to your habits',
            'This tag is either unclaimed or belongs to another account. '
                'To use it, open a habit and choose "Link NFC tag".',
          ),
        ];
      case _Phase.blank:
        return [
          _info(
            theme,
            Icons.new_label_outlined,
            'Unlinked tag',
            'This tag is empty. Open a habit and choose "Link NFC tag" to '
                'set it up.',
          ),
        ];
      case _Phase.unusable:
        return [
          _info(
            theme,
            Icons.block,
            "Can't use this tag",
            "It's locked by another app or not NFC-writable. Use a blank "
                'NTAG sticker instead.',
          ),
        ];
      case _Phase.error:
        return [
          _info(
            theme,
            Icons.error_outline,
            _problem?.title ?? 'Something went wrong',
            _problem?.detail ?? 'Try scanning again.',
          ),
        ];
    }
  }

  Widget _info(ThemeData theme, IconData icon, String title, String body) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
