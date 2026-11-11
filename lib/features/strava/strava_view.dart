import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/problem.dart';
import '../../data/strava_repository.dart';
import '../../session/session_controller.dart';
import '../../widgets/app_loader.dart';
import '../subscription/subscription_view.dart';
import '../subscription/tier.dart';
import 'strava_link.dart';

/// Strava's brand orange (Strava brand guidelines).
const stravaOrange = Color(0xFFFC4C02);

/// Strava proof needs this plan or higher (zinc's manifest says `pro`).
const _stravaMinTier = 'pro';

/// Profile → Strava: connect (after the consent screen), see the connection,
/// disconnect. Free users see an upsell instead of Connect.
class StravaView extends StatefulWidget {
  const StravaView({super.key});

  @override
  State<StravaView> createState() => _StravaViewState();
}

enum _Phase { loading, unavailable, ready, error }

class _StravaViewState extends State<StravaView> with WidgetsBindingObserver {
  late final SessionController _session;
  late final StravaRepository _strava;
  late final String _scheme;

  _Phase _phase = _Phase.loading;
  Problem? _error;
  StravaConnectionRes? _status;
  String? _tier;
  bool _busy = false;
  bool _waiting = false; // sent to Strava, waiting for the redirect back
  StravaLinkResult? _result;
  Problem? _actionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = context.read<SessionController>();
    _strava = StravaRepository(_session.auth.makeApiClient());
    _scheme = Uri.parse(_session.auth.config.redirectUri).scheme;
    StravaLinks.instance
      ..start(_scheme)
      ..pending.addListener(_onLink);
    _onLink();
    _load();
  }

  @override
  void dispose() {
    StravaLinks.instance.pending.removeListener(_onLink);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Strava or the browser: the redirect may not have reached us
    // (e.g. the user closed the tab), so re-read the connection either way.
    if (state == AppLifecycleState.resumed && mounted) _load();
  }

  void _onLink() {
    final r = StravaLinks.instance.consume();
    if (r == null || !mounted) return;
    setState(() {
      _result = r;
      _waiting = false;
    });
    _load();
  }

  Future<void> _load() async {
    final uid = _session.userId;
    if (uid == null) return;
    if (_status == null) setState(() => _phase = _Phase.loading);
    final statusCall = _strava.status(uid);
    final subCall = _session.subscriptions.current(uid);
    final status = await statusCall;
    final sub = await subCall;
    if (!mounted) return;
    setState(() {
      // Tier only gates the upsell; if it can't load, zinc still enforces.
      if (sub case Ok(:final value)) _tier = value.tier;
      switch (status) {
        case Ok(:final value):
          _status = value;
          _phase = _Phase.ready;
          if (value.connected) _waiting = false;
        case Err(:final problem):
          // zinc answers 404 on every Strava route where Strava is off.
          _phase = problem.status == 404 ? _Phase.unavailable : _Phase.error;
          _error = problem;
      }
    });
  }

  Future<void> _connect() async {
    final agreed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const StravaConsentView()));
    if (agreed != true || !mounted) return;
    final uid = _session.userId;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _actionError = null;
      _result = null;
    });
    final res = await _strava.connectUrl(uid);
    if (!mounted) return;
    switch (res) {
      case Ok(:final value):
        final opened = await openStravaAuthorize(value);
        if (!mounted) return;
        setState(() {
          _busy = false;
          if (opened case Err(:final problem)) {
            _actionError = problem;
          } else {
            _waiting = true;
          }
        });
      case Err(:final problem):
        setState(() {
          _busy = false;
          _actionError = problem;
        });
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Strava?'),
        content: const Text(
          'LazyTax is removed from your Strava account and your Strava data '
          'is deleted from LazyTax. Habits that used Strava go back to manual '
          'check-in. Days already completed stay completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final uid = _session.userId;
    if (uid == null) return;
    setState(() {
      _busy = true;
      _actionError = null;
      _result = null;
    });
    final res = await _strava.disconnect(uid);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (res) {
      case Ok():
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Strava disconnected')));
        _load();
      case Err(:final problem):
        setState(() => _actionError = problem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Strava')),
      body: switch (_phase) {
        _Phase.loading => const AppLoader(),
        _Phase.unavailable => const _Message(
          icon: Icons.directions_run,
          text: 'Strava isn’t available yet. Check back soon.',
        ),
        _Phase.error => _Message(
          icon: Icons.error_outline,
          text: _error?.displayMessage ?? 'Could not load Strava',
          onRetry: _load,
        ),
        _Phase.ready => _content(context),
      },
    );
  }

  Widget _content(BuildContext context) {
    final theme = Theme.of(context);
    final status = _status!;
    final allowed = tierMeets(_tier, _stravaMinTier);
    final since = status.connectedAtUtc?.toLocal();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_result != null)
            _ResultBanner(
              result: _result!,
              onDismiss: () => setState(() => _result = null),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.directions_run, color: stravaOrange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          status.connected
                              ? 'Connected'
                              : 'Complete habits with Strava',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status.connected
                        ? since == null
                              ? 'Your Strava account is connected.'
                              : 'Connected on ${MaterialLocalizations.of(context).formatMediumDate(since)}.'
                        : 'Bind a habit to Strava and it checks itself off '
                              'when you record a matching activity. You can '
                              'still check in by hand.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (status.connected) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Choose which habits use Strava in each habit’s '
                      'settings.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (status.connected)
            OutlinedButton.icon(
              onPressed: _busy ? null : _disconnect,
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect Strava'),
            )
          else if (!allowed)
            Card(
              child: ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Part of Pro and Ultimate'),
                subtitle: Text(
                  'You’re on the ${tierLabel(_tier ?? 'free')} plan. '
                  'Upgrade to complete habits with Strava.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubscriptionView()),
                  );
                  if (mounted) _load();
                },
              ),
            )
          else ...[
            ConnectWithStravaButton(onPressed: _busy ? null : _connect),
            if (_waiting) ...[
              const SizedBox(height: 12),
              Text(
                'Finish in Strava, then come back here.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          if (_busy) ...[
            const SizedBox(height: 12),
            const Center(
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          if (_actionError != null) ...[
            const SizedBox(height: 12),
            Text(
              _actionError!.displayMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const _PrivacyCard(),
        ],
      ),
    );
  }
}

/// Opens Strava's authorize page: in the Strava app when it can take the
/// `strava://` link, else in the system browser.
Future<Result<void>> openStravaAuthorize(StravaConnectUrlRes urls) async {
  try {
    final app = Uri.tryParse(urls.appUrl);
    if (app != null && app.scheme == 'strava' && await canLaunchUrl(app)) {
      if (await launchUrl(app, mode: LaunchMode.externalApplication)) {
        return const Ok(null);
      }
    }
    final web = Uri.tryParse(urls.url);
    if (web == null || web.scheme != 'https') {
      return Err(Problem.local('The server returned an unusable Strava link.'));
    }
    if (await launchUrl(web, mode: LaunchMode.externalApplication)) {
      return const Ok(null);
    }
    return Err(Problem.local('No browser was available to open Strava.'));
  } catch (e) {
    return Err(Problem.local('Could not open Strava', detail: '$e'));
  }
}

/// Strava's "Connect with Strava" button: brand orange, white label.
class ConnectWithStravaButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const ConnectWithStravaButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: stravaOrange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: stravaOrange.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        onPressed: onPressed,
        child: const Text('Connect with Strava'),
      ),
    );
  }
}

/// Shown before Strava's OAuth: what LazyTax reads, how to disconnect, how
/// to get the data deleted. Pops `true` when the user taps Connect.
class StravaConsentView extends StatelessWidget {
  const StravaConsentView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    Widget section(IconData icon, String title, String body) => Card(
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
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(body, style: muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Connect Strava')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Before you connect',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'LazyTax uses Strava only to check off the habits you bind to it.',
            style: muted,
          ),
          const SizedBox(height: 16),
          section(
            Icons.visibility_outlined,
            'What we read',
            'Only the sport type and start time of your activities. Not '
                'distance, pace, routes, photos or titles. Activities typed in '
                'by hand don’t count.',
          ),
          section(
            Icons.group_outlined,
            'What friends see',
            'Nothing from Strava. Friends you tell about a habit only hear '
                'that you missed it.',
          ),
          section(
            Icons.link_off,
            'Disconnect any time',
            'In Profile → Strava, or remove LazyTax in Strava under Settings → '
                'My Apps. Your Strava habits go back to manual check-in.',
          ),
          section(
            Icons.delete_outline,
            'Deleting your data',
            'Disconnecting deletes your Strava data from LazyTax straight '
                'away, and so does deleting your LazyTax account. To ask for '
                'deletion any other way, contact LazyTax support.',
          ),
          const SizedBox(height: 8),
          Text(
            'Strava’s own terms and privacy policy apply to your Strava '
            'account.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Wrap(
            children: [
              TextButton(
                onPressed: () => _open('https://www.strava.com/legal/terms'),
                child: const Text('Strava terms'),
              ),
              TextButton(
                onPressed: () => _open('https://www.strava.com/legal/privacy'),
                child: const Text('Strava privacy'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConnectWithStravaButton(
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  static Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // A legal page that won't open must not break the consent screen.
    }
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'LazyTax reads only the sport type and start time of your Strava '
      'activities and never shows Strava details to your friends. '
      'Disconnecting deletes your Strava data from LazyTax.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final StravaLinkResult result;
  final VoidCallback onDismiss;
  const _ResultBanner({required this.result, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ok = result.isSuccess;
    return Card(
      color: ok ? scheme.primaryContainer : scheme.errorContainer,
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle_outline : Icons.error_outline,
          color: ok ? scheme.onPrimaryContainer : scheme.onErrorContainer,
        ),
        title: Text(
          result.message,
          style: TextStyle(
            color: ok ? scheme.onPrimaryContainer : scheme.onErrorContainer,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          color: ok ? scheme.onPrimaryContainer : scheme.onErrorContainer,
          onPressed: onDismiss,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;
  const _Message({required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
