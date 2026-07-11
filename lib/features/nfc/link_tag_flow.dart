import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../core/problem.dart';
import '../../session/session_controller.dart';
import 'nfc_service.dart';

/// Links a physical NFC tag to [habitId] (plan Flow 1):
///
///   scan tag → blank: write `<base><uuid>` + lock · ours: reuse embedded id ·
///   foreign writable: confirm overwrite → rescan · locked foreign: reject
///   → GET resolve → already linked to another of my habits? confirm re-link
///   → PUT link (409 = someone else's tag).
///
/// All outcomes land as a SnackBar; the tag itself is only ever written once.
Future<void> runLinkTagFlow(
  BuildContext context, {
  required String habitId,
  required String habitName,
}) async {
  final session = context.read<SessionController>();
  final uid = session.userId;
  final messenger = ScaffoldMessenger.of(context);
  if (uid == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Sign in again to link a tag.')),
    );
    return;
  }

  final nfc = NfcService();
  final base = AppConfig.current.nfcTagBaseUrl;

  Future<Result<NfcScanResult>> scanOnce({required bool overwriteForeign}) {
    return nfc.scan(
      base: base,
      provision: true,
      candidateTagId: NfcService.newTagId(),
      overwriteForeign: overwriteForeign,
    );
  }

  void toast(String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  _showScanSheet(context, habitName: habitName);
  var result = await scanOnce(overwriteForeign: false);
  if (!context.mounted) return;
  _dismissScanSheet(context);

  // Foreign but writable → ask, then a second tap overwrites.
  if (result case Ok(value: NfcScanResult(kind: NfcTagKind.foreignWritable))) {
    final overwrite = await _confirm(
      context,
      title: 'Tag has other data',
      body:
          'This tag already contains something else. Overwrite it? '
          'This erases the old content permanently.',
      confirmLabel: 'Overwrite',
    );
    if (!context.mounted || !overwrite) return;
    _showScanSheet(context, habitName: habitName);
    result = await scanOnce(overwriteForeign: true);
    if (!context.mounted) return;
    _dismissScanSheet(context);
  }

  final NfcScanResult scan;
  switch (result) {
    case Ok(:final value):
      scan = value;
    case Err(:final problem):
      toast(problem.detail ?? problem.title);
      return;
  }

  final tagId = scan.tagId;
  switch (scan.kind) {
    case NfcTagKind.unusable:
      toast(
        "This tag can't be used — it's locked by another app. "
        'Use a blank NFC sticker instead.',
      );
      return;
    case NfcTagKind.blank:
    case NfcTagKind.foreignWritable:
      // Only reachable from the read-only paths — provision covers these.
      toast('Could not prepare the tag. Try again.');
      return;
    case NfcTagKind.lazytax:
      if (tagId == null) {
        toast('Could not read the tag id. Try scanning again.');
        return;
      }
  }

  // Already pointing at another of my habits? Ask before stealing it.
  // (404 = fresh/unclaimed — expected, proceed silently. Any other failure
  // aborts: linking blind could silently re-point an existing mapping.)
  if (!scan.provisioned) {
    final resolved = await session.nfcTags.resolve(uid, tagId);
    if (!context.mounted) return;
    switch (resolved) {
      case Ok(:final value):
        if (value.tag.habitId == habitId) {
          toast('This tag already completes "$habitName".');
          return;
        }
        final relink = await _confirm(
          context,
          title: 'Tag already linked',
          body:
              'This tag currently completes "${value.habitVersion.task ?? 'another habit'}". '
              'Re-link it to "$habitName" instead?',
          confirmLabel: 'Re-link',
        );
        if (!context.mounted || !relink) return;
      case Err(:final problem) when problem.status != 404:
        toast(problem.detail ?? problem.title);
        return;
      case Err():
        break; // 404 — unclaimed, proceed
    }
  }

  final linked = await session.nfcTags.link(uid, tagId, habitId);
  if (!context.mounted) return;
  switch (linked) {
    case Ok():
      toast('✅ Tag linked to "$habitName" — tap it any day to complete.');
    case Err(:final problem):
      toast(
        problem.status == 409
            ? 'This tag belongs to another account. Use a different sticker.'
            : (problem.detail ?? problem.title),
      );
  }
}

/// Android has no system NFC sheet, so show our own "hold the phone near the
/// tag" instructions while the session polls. On iOS this sits behind the
/// system sheet, which is fine.
void _showScanSheet(BuildContext context, {required String habitName}) {
  showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    routeSettings: const RouteSettings(name: _scanSheetRoute),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nfc, size: 48),
            const SizedBox(height: 12),
            Text(
              'Link a tag to "$habitName"',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Hold your phone near the NFC tag…',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}

const _scanSheetRoute = 'nfc-scan-sheet';

void _dismissScanSheet(BuildContext context) {
  Navigator.of(
    context,
  ).popUntil((route) => route.settings.name != _scanSheetRoute);
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return answer ?? false;
}
