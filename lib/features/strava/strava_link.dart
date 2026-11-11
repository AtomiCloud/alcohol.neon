import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

/// How Strava's OAuth ended, from zinc's redirect to
/// `<app scheme>://strava?result=…`.
enum StravaLinkResult {
  connected,
  denied,
  scopeMissing,
  athleteTaken,
  expired,
  error;

  bool get isSuccess => this == StravaLinkResult.connected;

  /// What to tell the user.
  String get message => switch (this) {
    connected => 'Strava is connected.',
    denied => 'Strava wasn’t connected: you cancelled or declined access.',
    scopeMissing =>
      'Strava wasn’t connected: allow LazyTax to see your activities '
          '(including private ones) and try again.',
    athleteTaken =>
      'That Strava account is already connected to another LazyTax account.',
    expired => 'The Strava sign-in took too long. Please try again.',
    error => 'Something went wrong connecting Strava. Please try again.',
  };
}

/// Parses zinc's Strava redirect. Null when [uri] isn't one (wrong scheme or
/// host, e.g. the Logto `…://callback` or an NFC tag link); an unknown or
/// missing `result` counts as [StravaLinkResult.error].
StravaLinkResult? stravaResultFromUri(Uri uri, String appScheme) {
  if (uri.scheme.toLowerCase() != appScheme.toLowerCase()) return null;
  if (uri.host.toLowerCase() != 'strava') return null;
  return switch (uri.queryParameters['result']) {
    'connected' => StravaLinkResult.connected,
    'denied' => StravaLinkResult.denied,
    'scope_missing' => StravaLinkResult.scopeMissing,
    'athlete_taken' => StravaLinkResult.athleteTaken,
    'expired' => StravaLinkResult.expired,
    _ => StravaLinkResult.error,
  };
}

/// Catches the Strava redirect deep link. Started by the Strava screen, which
/// stays on the stack while the user is in Strava or the browser, so a warm
/// return lands in [pending]. A cold start through the link (the app was
/// killed meanwhile) is picked up once from app_links' initial link.
class StravaLinks {
  StravaLinks._();
  static final instance = StravaLinks._();

  final pending = ValueNotifier<StravaLinkResult?>(null);
  StreamSubscription<Uri>? _sub;
  bool _checkedInitial = false;

  void start(String appScheme) {
    _sub ??= AppLinks().uriLinkStream.listen((uri) {
      final r = stravaResultFromUri(uri, appScheme);
      if (r != null) pending.value = r;
    });
    if (_checkedInitial) return;
    _checkedInitial = true;
    AppLinks().getInitialLink().then(
      (uri) {
        final r = uri == null ? null : stravaResultFromUri(uri, appScheme);
        if (r != null) pending.value = r;
      },
      onError: (Object _) {
        // No initial link to read on this platform; warm links still arrive.
      },
    );
  }

  StravaLinkResult? consume() {
    final r = pending.value;
    pending.value = null;
    return r;
  }
}
