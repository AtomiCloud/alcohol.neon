import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../session/session_controller.dart';
import '../friends/friend_relation.dart';
import '../friends/friends_view.dart';
import 'ndef_uri.dart';
import 'tap_complete_view.dart';

/// Holds the tag id from an incoming `/t/{tagId}` Universal/App Link, or the
/// code from a `/f/{code}` friend invite link on the same host, until the
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
  String? _pendingInviteCode;

  NfcDeepLinkService({Stream<Uri> Function()? links})
    : _links = links ?? (() => AppLinks().uriLinkStream);

  String? get pendingTagId => _pendingTagId;
  String? get pendingInviteCode => _pendingInviteCode;

  void start(Uri nfcTagBase) {
    _sub ??= _links().listen((uri) {
      final tagId = tagIdFromUri(uri, nfcTagBase);
      final code = tagId == null ? inviteCodeFromUri(uri, nfcTagBase) : null;
      if (tagId == null && code == null) return;
      if (tagId != null) _pendingTagId = tagId;
      if (code != null) _pendingInviteCode = code;
      notifyListeners();
    });
  }

  String? consumeInvite() {
    final code = _pendingInviteCode;
    _pendingInviteCode = null;
    return code;
  }

  /// `https://<tag host>/f/{code}` → code; other hosts and paths → null.
  static String? inviteCodeFromUri(Uri uri, Uri base) =>
      uri.scheme == 'https' &&
          uri.host == base.host &&
          uri.pathSegments.length >= 2 &&
          uri.pathSegments.first == 'f'
      ? inviteCodeFrom(uri.pathSegments[1])
      : null;

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

/// Wraps the ready authed shell; when a tag or invite link is pending (or
/// arrives) and the session is ready, pushes [TapCompleteView] or
/// [FriendsView] (which uses the invite) on the enclosing navigator.
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

    if ((links.pendingTagId != null || links.pendingInviteCode != null) &&
        session.phase == SessionPhase.ready &&
        !_navigating) {
      _navigating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final tagId = links.consume();
        final code = tagId == null ? links.consumeInvite() : null;
        if (mounted && (tagId != null || code != null)) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => tagId != null
                  ? TapCompleteView(tagId: tagId)
                  : FriendsView(inviteCode: code),
            ),
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
