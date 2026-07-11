import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../session/session_controller.dart';
import 'ndef_uri.dart';
import 'tap_complete_view.dart';

/// Holds the tag id from an incoming `/t/{tagId}` Universal/App Link until the
/// authed shell is ready to act on it. A cold-start tap arrives before
/// sign-in/bootstrap complete, so the link is parked here and consumed by
/// [NfcTapListener] once the session reaches `ready`.
class NfcDeepLinkService extends ChangeNotifier {
  /// Injectable for tests; defaults to the platform stream, which (app_links
  /// ≥6) also replays the link that launched the app, so cold and warm starts
  /// take the same path.
  final Stream<Uri> Function() _links;
  StreamSubscription<Uri>? _sub;
  String? _pendingTagId;

  NfcDeepLinkService({Stream<Uri> Function()? links})
    : _links = links ?? (() => AppLinks().uriLinkStream);

  String? get pendingTagId => _pendingTagId;

  void start(Uri nfcTagBase) {
    _sub ??= _links().listen((uri) {
      final tagId = tagIdFromUri(uri, nfcTagBase);
      if (tagId == null) return;
      _pendingTagId = tagId;
      notifyListeners();
    });
  }

  String? consume() {
    final id = _pendingTagId;
    _pendingTagId = null;
    return id;
  }

  /// `https://<host>/t/{tagId}` (optionally with a trailing slash) → tagId.
  /// Delegates to the same parser used for on-tag URLs so both stay in sync.
  static String? tagIdFromUri(Uri uri, Uri base) =>
      tagIdFromUrl(uri.toString(), base);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Wraps the ready authed shell; when a tag link is pending (or arrives) and
/// the session is ready, pushes [TapCompleteView] on the enclosing navigator.
class NfcTapListener extends StatefulWidget {
  final Widget child;
  const NfcTapListener({super.key, required this.child});

  @override
  State<NfcTapListener> createState() => _NfcTapListenerState();
}

class _NfcTapListenerState extends State<NfcTapListener> {
  bool _navigating = false;

  @override
  Widget build(BuildContext context) {
    final links = context.watch<NfcDeepLinkService>();
    final session = context.watch<SessionController>();

    if (links.pendingTagId != null &&
        session.phase == SessionPhase.ready &&
        !_navigating) {
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final tagId = links.consume();
        if (tagId != null && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TapCompleteView(tagId: tagId)),
          );
        }
        // setState, not a bare assignment: a link that arrived *while* we were
        // navigating is parked in the service, and only a rebuild re-checks it.
        if (mounted) setState(() => _navigating = false);
      });
    }

    return widget.child;
  }
}
