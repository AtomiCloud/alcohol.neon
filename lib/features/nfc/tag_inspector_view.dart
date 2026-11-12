import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../core/problem.dart';
import '../../data/nfc_tag_repository.dart';
import '../../session/session_controller.dart';
import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/glass_page.dart';
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
  Problem? _actionError;
  bool _acting = false;

  Future<void> _scan() async {
    setState(() {
      _phase = _Phase.scanning;
      _tagId = null;
      _resolution = null;
      _problem = null;
      _actionError = null;
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
    final ok = await showGlassConfirm(
      context,
      title: 'Unlink this tag?',
      message:
          'Tapping it will no longer complete '
          '"${_resolution?.habitVersion.task ?? 'this habit'}". '
          'You can link it to any habit afterwards.',
      confirmLabel: 'Unlink',
    );
    if (!ok || !mounted) return;

    setState(() {
      _acting = true;
      _actionError = null;
    });
    final res = await session.nfcTags.unlink(uid, tagId);
    if (!mounted) return;
    setState(() => _acting = false);
    switch (res) {
      case Ok():
        showGlassToast(context, 'Tag unlinked — it can be reused.');
        setState(() => _phase = _Phase.notYours);
      case Err(:final problem):
        setState(() => _actionError = problem);
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
    final scanning = _phase == _Phase.scanning;
    // One emerald action: Scan, unless the tag's habit can be completed now.
    final canComplete =
        _phase == _Phase.yours && _resolution?.todayExecution == null;
    return GlassPage(
      title: 'NFC tags',
      dock: GlassButton(
        label: scanning
            ? 'Scanning…'
            : _phase == _Phase.idle
            ? 'Scan a tag'
            : 'Scan another tag',
        busy: scanning,
        secondary: canComplete,
        onPressed: scanning ? null : _scan,
      ),
      children: [
        if (_actionError case final e?)
          GlassBanner(
            icon: Icons.error_outline_rounded,
            title: e.title,
            body: e.detail,
            error: true,
          ),
        ..._result(context),
      ],
    );
  }

  List<Widget> _result(BuildContext context) {
    final t = GlassTokens.of(context);
    switch (_phase) {
      case _Phase.idle:
      case _Phase.scanning:
        return [
          const SizedBox(height: 16),
          GlassMessage(
            icon: Icons.nfc_rounded,
            tint: t.accent,
            // The Scan button shows the spinner while it scans.
            title: _phase == _Phase.scanning
                ? 'Hold your phone near the tag'
                : 'What does this tag do?',
            body:
                'Scan a tag to see which habit it completes. '
                'Scanning here never completes the habit.',
          ),
        ];
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
          GlassSection(
            title: 'This tag completes',
            footer:
                'To point this tag at a different habit, open that habit '
                'and choose "Link NFC tag".',
            children: [
              GlassRow(
                leading: IconTile(Icons.nfc_rounded, t.accent),
                title: r.habitVersion.task ?? 'Habit',
                subtitle: subtitle,
              ),
            ],
          ),
          GlassSection(
            dividerIndent: 16,
            children: [
              if (today == null)
                GlassRow(
                  title: 'Complete now',
                  accent: true,
                  centered: true,
                  onTap: _complete,
                ),
              GlassRow(
                title: 'Unlink tag',
                destructive: true,
                centered: true,
                trailing: _acting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _acting ? null : _unlink,
              ),
            ],
          ),
        ];
      case _Phase.notYours:
        return const [
          GlassBanner(
            icon: Icons.help_outline_rounded,
            title: 'Not linked to your habits',
            body:
                'This tag is either unclaimed or belongs to another account. '
                'To use it, open a habit and choose "Link NFC tag".',
          ),
        ];
      case _Phase.blank:
        return const [
          GlassBanner(
            icon: Icons.new_label_outlined,
            title: 'Unlinked tag',
            body:
                'This tag is empty. Open a habit and choose "Link NFC tag" to '
                'set it up.',
          ),
        ];
      case _Phase.unusable:
        return const [
          GlassBanner(
            icon: Icons.block_rounded,
            title: "Can't use this tag",
            body:
                "It's locked by another app or not NFC-writable. Use a blank "
                'NTAG sticker instead.',
            error: true,
          ),
        ];
      case _Phase.error:
        return [
          GlassBanner(
            icon: Icons.error_outline_rounded,
            title: _problem?.title ?? 'Something went wrong',
            body: _problem?.detail ?? 'Try scanning again.',
            error: true,
          ),
        ];
    }
  }
}
