import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../core/problem.dart';
import '../../session/session_controller.dart';
import '../../theme/glass.dart';
import '../../widgets/glass_modal.dart';
import 'nfc_service.dart';

/// Links a physical NFC tag to [habitId] (plan Flow 1):
///
///   scan tag → blank: write `<base><uuid>` + lock · ours: reuse embedded id ·
///   foreign writable: confirm overwrite → rescan · locked foreign: reject
///   → GET resolve → already linked to another of my habits? confirm re-link
///   → PUT link (409 = someone else's tag).
///
/// The flow is a glass sheet while it scans, a glass confirm before it
/// overwrites or re-links, and a glass toast for every outcome (it has no
/// page of its own); the tag itself is only ever written once.
/// Returns whether the tag now completes [habitId].
Future<bool> runLinkTagFlow(
  BuildContext context, {
  required String habitId,
  required String habitName,
}) async {
  final session = context.read<SessionController>();
  final uid = session.userId;
  if (uid == null) {
    showGlassToast(context, 'Sign in again to link a tag.');
    return false;
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

  void toast(String message) => showGlassToast(context, message);

  _showScanSheet(context, habitName: habitName);
  var result = await scanOnce(overwriteForeign: false);
  if (!context.mounted) return false;
  _dismissScanSheet(context);

  // Foreign but writable → ask, then a second tap overwrites.
  if (result case Ok(value: NfcScanResult(kind: NfcTagKind.foreignWritable))) {
    final overwrite = await showGlassConfirm(
      context,
      title: 'Tag has other data',
      message:
          'This tag already contains something else. Overwrite it? '
          'This erases the old content permanently.',
      confirmLabel: 'Overwrite',
    );
    if (!context.mounted || !overwrite) return false;
    _showScanSheet(context, habitName: habitName);
    result = await scanOnce(overwriteForeign: true);
    if (!context.mounted) return false;
    _dismissScanSheet(context);
  }

  final NfcScanResult scan;
  switch (result) {
    case Ok(:final value):
      scan = value;
    case Err(:final problem):
      toast(problem.detail ?? problem.title);
      return false;
  }

  final tagId = scan.tagId;
  switch (scan.kind) {
    case NfcTagKind.unusable:
      toast(
        "This tag can't be used — it's locked by another app. "
        'Use a blank NFC sticker instead.',
      );
      return false;
    case NfcTagKind.blank:
    case NfcTagKind.foreignWritable:
      // Only reachable from the read-only paths — provision covers these.
      toast('Could not prepare the tag. Try again.');
      return false;
    case NfcTagKind.lazytax:
      if (tagId == null) {
        toast('Could not read the tag id. Try scanning again.');
        return false;
      }
  }

  // Already pointing at another of my habits? Ask before stealing it.
  // (404 = fresh/unclaimed — expected, proceed silently. Any other failure
  // aborts: linking blind could silently re-point an existing mapping.)
  if (!scan.provisioned) {
    final resolved = await session.nfcTags.resolve(uid, tagId);
    if (!context.mounted) return false;
    switch (resolved) {
      case Ok(:final value):
        if (value.tag.habitId == habitId) {
          toast('This tag already completes "$habitName".');
          return true;
        }
        final relink = await showGlassConfirm(
          context,
          title: 'Tag already linked',
          destructive: false,
          message:
              'This tag currently completes "${value.habitVersion.task ?? 'another habit'}". '
              'Re-link it to "$habitName" instead?',
          confirmLabel: 'Re-link',
        );
        if (!context.mounted || !relink) return false;
      case Err(:final problem) when problem.status != 404:
        toast(problem.detail ?? problem.title);
        return false;
      case Err():
        break; // 404 — unclaimed, proceed
    }
  }

  final linked = await session.nfcTags.link(uid, tagId, habitId);
  if (!context.mounted) return false;
  switch (linked) {
    case Ok():
      toast('✅ Tag linked to "$habitName" — tap it any day to complete.');
      return true;
    case Err(:final problem):
      toast(
        problem.status == 409
            ? 'This tag belongs to another account. Use a different sticker.'
            : (problem.detail ?? problem.title),
      );
      return false;
  }
}

/// Android has no system NFC sheet, so show our own "hold the phone near the
/// tag" instructions while the session polls. On iOS this sits behind the
/// system sheet, which is fine.
void _showScanSheet(BuildContext context, {required String habitName}) {
  showGlassSheet<void>(
    context,
    dismissible: false,
    routeSettings: const RouteSettings(name: _scanSheetRoute),
    (ctx) {
      final theme = Theme.of(ctx);
      final t = GlassTokens.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.accent.withValues(alpha: 0.14),
                ),
                child: Icon(Icons.nfc_rounded, size: 36, color: t.accent),
              ),
              const SizedBox(height: 16),
              Text(
                'Link a tag to "$habitName"',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Hold your phone near the NFC tag…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
              ),
              const SizedBox(height: 20),
              SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: t.accent,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

const _scanSheetRoute = 'nfc-scan-sheet';

void _dismissScanSheet(BuildContext context) {
  Navigator.of(
    context,
  ).popUntil((route) => route.settings.name != _scanSheetRoute);
}
