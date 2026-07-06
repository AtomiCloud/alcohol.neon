import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/problem.dart';
import '../../data/subscription_repository.dart';
import '../../generated/zinc/models/subscription_cta_res.dart';
import '../../services/storefront_service.dart';

/// The CTA the screen may render. Unknown server variants map to [neutral] so
/// new variants can ship server-side without breaking old app builds.
enum SubscriptionCtaVariant { manage, subscribe, neutral }

/// State for the subscription screen: resolves the storefront, asks zinc which
/// CTA to show, and on tap mints the web-handoff magic link and opens it in
/// the system browser (never in-app — the OTT signs the user in on the web).
class SubscriptionController extends ChangeNotifier {
  final SubscriptionRepository _repo;
  final StorefrontService _storefront;
  final String _userId;

  /// Injectable for tests; production uses url_launcher's external browser.
  final Future<bool> Function(Uri) _launcher;

  SubscriptionController({
    required SubscriptionRepository repository,
    required StorefrontService storefront,
    required String userId,
    Future<bool> Function(Uri)? launcher,
  }) : _repo = repository,
       _storefront = storefront,
       _userId = userId,
       _launcher =
           launcher ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  bool _loading = true;
  Problem? _error;
  SubscriptionCtaRes? _cta;
  StorefrontInfo? _storefrontInfo;
  bool _opening = false;
  Problem? _openError;
  bool _disposed = false;

  bool get loading => _loading;
  Problem? get error => _error;
  String? get tier => _cta?.tier;
  bool get opening => _opening;
  Problem? get openError => _openError;

  SubscriptionCtaVariant get variant => switch (_cta?.variant) {
    'manage' => SubscriptionCtaVariant.manage,
    'subscribe' => SubscriptionCtaVariant.subscribe,
    // null, 'neutral' and any variant this build doesn't know -> neutral
    // (never steer unless the server explicitly said we may).
    _ => SubscriptionCtaVariant.neutral,
  };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The screen can be popped while a request is in flight; notifying a
  /// disposed ChangeNotifier trips a debug assertion.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    // Full-screen loader only before the first result; later calls (e.g. the
    // on-resume refresh after subscribing in the browser) update in place.
    _loading = _cta == null;
    _error = null;
    _notify();

    final info = await _storefront.resolve();
    _storefrontInfo = info;
    final res = await _repo.cta(
      _userId,
      platform: info.platform,
      storefront: info.countryCode,
    );
    switch (res) {
      case Ok(:final value):
        _cta = value;
        _loading = false;
      case Err(:final problem):
        _error = problem;
        _loading = false;
    }
    _notify();
  }

  /// Mints the magic link and opens it in the default browser. The URL is a
  /// live one-time login credential: https-only, system browser only.
  Future<void> openPortal() async {
    final info = _storefrontInfo ?? await _storefront.resolve();
    _opening = true;
    _openError = null;
    _notify();

    final res = await _repo.webHandoff(
      platform: info.platform,
      storefront: info.countryCode,
    );
    switch (res) {
      case Ok(:final value):
        final uri = Uri.tryParse(value.url ?? '');
        if (uri == null || uri.scheme != 'https') {
          _openError = Problem.local(
            'Could not open the billing portal',
            type: 'neon:handoff',
            detail: 'The server returned an unusable portal link.',
          );
        } else {
          final ok = await _launcher(uri);
          if (!ok) {
            _openError = Problem.local(
              'Could not open the browser',
              type: 'neon:handoff',
              detail: 'No browser was available to open the billing portal.',
            );
          }
        }
      case Err(:final problem):
        _openError = problem;
    }
    _opening = false;
    _notify();
  }
}
