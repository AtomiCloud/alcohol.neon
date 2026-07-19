import 'dart:async';
import 'dart:math';

import 'package:nfc_manager/nfc_manager.dart';

import '../../core/problem.dart';
import 'ndef_uri.dart';

/// What a physical tag turned out to be after a scan.
enum NfcTagKind {
  /// Carries one of our URLs — [NfcScanResult.tagId] is set.
  lazytax,

  /// NDEF-formatted with no records (a fresh sticker).
  blank,

  /// Carries someone else's data but is still writable (overwritable after
  /// user confirmation).
  foreignWritable,

  /// Not usable: locked with foreign data, not NDEF, or NDEF but not writable
  /// when a write was needed.
  unusable,
}

class NfcScanResult {
  final NfcTagKind kind;
  final String? tagId;

  /// True when this scan wrote (and locked) a fresh tag.
  final bool provisioned;

  const NfcScanResult(this.kind, {this.tagId, this.provisioned = false});
}

/// Wraps the platform NFC session (nfc_manager) behind `Result`, so callers
/// never see plugin exceptions. One physical tap = one [scan] call.
///
/// A scan can optionally *provision*: when the tag is blank (or foreign and
/// [overwriteForeign] is set), it writes `<base><candidateTagId>` as an NDEF
/// URI record and permanently locks the tag. Locking is safe for re-linking —
/// re-linking only updates zinc's mapping, never the tag.
class NfcService {
  /// Generates a fresh tag id (UUID v4, matches zinc's `^[A-Za-z0-9-]{8,64}$`).
  static String newTagId() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
    String hex(int start, int end) => bytes
        .sublist(start, end)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  Future<bool> isAvailable() {
    return NfcManager.instance.isAvailable();
  }

  /// Runs one NFC session until a tag is tapped (or [timeout] passes — iOS
  /// shows its own system sheet with a cancel button; Android polls silently).
  ///
  /// Read-only when [provision] is false (the inspector). When true, a blank
  /// tag is written with `<base><candidateTagId>` + locked; a foreign writable
  /// tag is only overwritten when [overwriteForeign] is set (the caller asks
  /// the user first and runs a second scan).
  Future<Result<NfcScanResult>> scan({
    required Uri base,
    bool provision = false,
    String? candidateTagId,
    bool overwriteForeign = false,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (!await isAvailable()) {
      return Err(
        Problem.local(
          'NFC is not available',
          type: 'neon:nfc',
          detail:
              'This device cannot scan NFC tags (or NFC is turned off in system settings).',
        ),
      );
    }
    assert(
      !provision || candidateTagId != null,
      'provision requires a candidateTagId',
    );

    final completer = Completer<Result<NfcScanResult>>();

    // stop=false when iOS already invalidated the session (onError) — calling
    // stopSession again would throw. stopSession itself is wrapped anyway:
    // double-stops are harmless on both platforms, but never fatal here.
    Future<void> finish(
      Result<NfcScanResult> result, {
      bool stop = true,
    }) async {
      if (completer.isCompleted) return;
      if (stop) {
        try {
          // iOS: the system sheet shows this text; Android ignores it.
          switch (result) {
            case Ok(:final value):
              switch (value.kind) {
                case NfcTagKind.lazytax:
                  await NfcManager.instance.stopSession(alertMessage: 'Done');
                case NfcTagKind.blank:
                  await NfcManager.instance.stopSession(
                    alertMessage: 'Empty tag',
                  );
                case NfcTagKind.foreignWritable:
                  await NfcManager.instance.stopSession(
                    errorMessage: 'Tag has other data',
                  );
                case NfcTagKind.unusable:
                  await NfcManager.instance.stopSession(
                    errorMessage: 'Tag not usable',
                  );
              }
            case Err(:final problem):
              await NfcManager.instance.stopSession(
                errorMessage: problem.title,
              );
          }
        } catch (_) {
          // Session already gone — nothing to stop.
        }
      }
      completer.complete(result);
    }

    try {
      await NfcManager.instance.startSession(
        // Only the technologies our tags use (NTAG21x = iso14443, Type-5 =
        // iso15693). The plugin's default adds iso18092 (FeliCa), which iOS
        // refuses without felica.systemcodes in Info.plist — nfcd then kills
        // the session with a misleading "Missing required entitlement".
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        alertMessage: 'Hold your iPhone near the tag',
        // User-cancel / system invalidation only surfaces here — without this
        // handler a cancelled iOS sheet would hang the flow until [timeout].
        onError: (NfcError error) async {
          await finish(
            Err(
              Problem.local(
                'Scan cancelled',
                type: 'neon:nfc',
                detail: error.message,
              ),
            ),
            stop: false, // the session is already invalidated
          );
        },
        onDiscovered: (NfcTag tag) async {
          try {
            await finish(
              await _handleTag(
                tag,
                base: base,
                provision: provision,
                candidateTagId: candidateTagId,
                overwriteForeign: overwriteForeign,
              ),
            );
          } catch (e) {
            await finish(
              Err(
                Problem.local(
                  'Tag read failed',
                  type: 'neon:nfc',
                  detail: 'Keep the phone still on the tag and try again. ($e)',
                ),
              ),
            );
          }
        },
      );
    } catch (e) {
      return Err(
        Problem.local(
          'Could not start NFC scan',
          type: 'neon:nfc',
          detail: '$e',
        ),
      );
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () async {
        // Complete through finish() so a tap racing the deadline can't also
        // complete (and so the session actually stops).
        final err = Err<NfcScanResult>(
          Problem.local(
            'No tag detected',
            type: 'neon:nfc',
            detail: 'No tag was tapped in time. Try again.',
          ),
        );
        await finish(err);
        return err;
      },
    );
  }

  Future<Result<NfcScanResult>> _handleTag(
    NfcTag tag, {
    required Uri base,
    required bool provision,
    String? candidateTagId,
    required bool overwriteForeign,
  }) async {
    final ndef = Ndef.from(tag);
    if (ndef == null) {
      return const Ok(NfcScanResult(NfcTagKind.unusable));
    }

    // What's on it already?
    final cached = ndef.cachedMessage;
    final records = cached?.records ?? const [];
    for (final r in records) {
      if (r.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
          r.type.length == 1 &&
          r.type.first == 0x55 /* 'U' */ ) {
        final url = decodeNdefUriPayload(r.payload);
        final tagId = url == null ? null : tagIdFromUrl(url, base);
        if (tagId != null) {
          // Ours (or merch): reuse the embedded id — never rewrite.
          return Ok(NfcScanResult(NfcTagKind.lazytax, tagId: tagId));
        }
      }
    }

    final isBlank =
        records.isEmpty ||
        records.every(
          (r) =>
              r.typeNameFormat == NdefTypeNameFormat.empty || r.payload.isEmpty,
        );

    if (!provision) {
      return Ok(
        NfcScanResult(
          isBlank
              ? NfcTagKind.blank
              : (ndef.isWritable
                    ? NfcTagKind.foreignWritable
                    : NfcTagKind.unusable),
        ),
      );
    }

    if (!ndef.isWritable) {
      // Locked with foreign data (or read-only blank) — nothing we can do.
      return const Ok(NfcScanResult(NfcTagKind.unusable));
    }
    if (!isBlank && !overwriteForeign) {
      // Ask first; the caller confirms and runs a second scan.
      return const Ok(NfcScanResult(NfcTagKind.foreignWritable));
    }

    final id = candidateTagId!;
    // Tolerate a config value without the trailing slash — '$base$id' would
    // otherwise silently produce /t<id> instead of /t/<id>.
    final baseStr = '$base';
    final url = Uri.parse(
      baseStr.endsWith('/') ? '$baseStr$id' : '$baseStr/$id',
    );
    await ndef.write(NdefMessage([NdefRecord.createUri(url)]));
    // Permanent, deliberate: a locked tag can't be hijacked with a different
    // URL. Re-linking to another habit never needs a rewrite (zinc-side remap).
    // Known 3.x limitation: Android's plugin ignores makeReadOnly()'s boolean,
    // so a tag that refuses locking still reports success — the URL is written
    // either way; only the tamper-proofing is best-effort there.
    await ndef.writeLock();
    return Ok(NfcScanResult(NfcTagKind.lazytax, tagId: id, provisioned: true));
  }
}
