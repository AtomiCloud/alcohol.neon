import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/problem.dart';
import '../../data/strava_repository.dart';
import '../../session/session_controller.dart';
import '../../theme/glass.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/glass_page.dart';
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
    final confirmed = await showGlassConfirm(
      context,
      title: 'Disconnect Strava?',
      message:
          'LazyTax is removed from your Strava account and your Strava data '
          'is deleted from LazyTax. Habits that used Strava go back to manual '
          'check-in. Days already completed stay completed.',
      confirmLabel: 'Disconnect',
    );
    if (!confirmed || !mounted) return;
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
        showGlassToast(context, 'Strava disconnected');
        _load();
      case Err(:final problem):
        setState(() => _actionError = problem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Strava',
      onRefresh: _phase == _Phase.ready ? _load : null,
      children: switch (_phase) {
        _Phase.loading => const [SizedBox(height: 320, child: AppLoader())],
        _Phase.unavailable => [
          const SizedBox(height: 8),
          const GlassBanner(
            icon: Icons.directions_run_rounded,
            title: 'Strava isn’t available yet',
            body: 'Check back soon.',
          ),
        ],
        _Phase.error => [
          GlassBanner(
            icon: Icons.cloud_off_rounded,
            title: _error?.displayMessage ?? 'Could not load Strava',
            error: true,
            action: GlassTextButton(label: 'Retry', onPressed: _load),
          ),
        ],
        _Phase.ready => _content(context),
      },
    );
  }

  List<Widget> _content(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final status = _status!;
    final connected = status.connected;
    final allowed = tierMeets(_tier, _stravaMinTier);
    final since = status.connectedAtUtc?.toLocal();
    final result = _result;
    return [
      if (result != null)
        GlassBanner(
          icon: result.isSuccess
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          title: result.message,
          error: !result.isSuccess,
          action: IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => setState(() => _result = null),
          ),
        ),
      if (_actionError case final error?)
        GlassBanner(
          icon: Icons.error_outline_rounded,
          title: error.displayMessage,
          error: true,
        ),
      const SizedBox(height: 8),
      Glass(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(alignment: Alignment.centerLeft, child: StravaGlyph()),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    connected ? 'Connected' : 'Not connected',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: connected ? t.accent : t.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (connected && since != null)
                  Text(
                    'Since ${MaterialLocalizations.of(context).formatMediumDate(since)}',
                    style: theme.textTheme.labelLarge?.copyWith(color: t.muted),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              connected
                  ? 'Habits check themselves off'
                  : 'Complete habits with Strava',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              connected
                  ? 'Choose which habits use Strava in each habit’s settings. '
                        'You can still check in by hand.'
                  : 'Bind a habit to Strava and it checks itself off when '
                        'you record a matching activity. You can still check '
                        'in by hand.',
              style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
            ),
            if (!connected && allowed) ...[
              const SizedBox(height: 16),
              ConnectWithStravaButton(onPressed: _busy ? null : _connect),
              if (_waiting) ...[
                const SizedBox(height: 10),
                Text(
                  'Finish in Strava, then come back here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
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
          ],
        ),
      ),
      if (!connected && !allowed)
        GlassSection(
          title: 'Plan',
          children: [
            GlassRow(
              leading: const Icon(Icons.lock_outline_rounded),
              title: 'Part of Pro and Ultimate',
              subtitle:
                  'You’re on the ${tierLabel(_tier ?? 'free')} plan. '
                  'Upgrade to complete habits with Strava.',
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionView()),
                );
                if (mounted) _load();
              },
            ),
          ],
        ),
      const GlassFooter(
        'LazyTax reads only the sport type and start time of your Strava '
        'activities and never shows Strava details to your friends. '
        'Disconnecting deletes your Strava data from LazyTax.',
      ),
      if (connected) ...[
        const SizedBox(height: 20),
        Glass(
          child: GlassRow(
            leading: const Icon(Icons.link_off_rounded),
            title: 'Disconnect Strava',
            destructive: true,
            chevron: false,
            onTap: _busy ? null : _disconnect,
          ),
        ),
      ],
    ];
  }
}

/// Strava's run glyph on an orange-tinted disc.
class StravaGlyph extends StatelessWidget {
  final double size;
  const StravaGlyph({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: stravaOrange.withValues(alpha: 0.15),
      shape: BoxShape.circle,
    ),
    child: SizedBox.square(
      dimension: size,
      child: Icon(
        Icons.directions_run_rounded,
        size: size * 0.5,
        color: stravaOrange,
      ),
    ),
  );
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
    final t = GlassTokens.of(context);
    Widget point(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: t.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return GlassPage(
      title: 'Connect Strava',
      dock: ConnectWithStravaButton(
        onPressed: () => Navigator.of(context).pop(true),
      ),
      children: [
        const SizedBox(height: 4),
        Glass(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StravaGlyph(),
              const SizedBox(height: 14),
              Text(
                'Before you connect',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'LazyTax uses Strava only to check off the habits you bind '
                'to it.',
                style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Glass(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              point(
                Icons.visibility_outlined,
                'What we read',
                'Only the sport type and start time of your activities. Not '
                    'distance, pace, routes, photos or titles. Activities '
                    'typed in by hand don’t count.',
              ),
              point(
                Icons.group_outlined,
                'What friends see',
                'Nothing from Strava. Friends you tell about a habit only '
                    'hear that you missed it.',
              ),
              point(
                Icons.link_off_rounded,
                'Disconnect any time',
                'In Profile → Strava, or remove LazyTax in Strava under '
                    'Settings → My Apps. Your Strava habits go back to manual '
                    'check-in.',
              ),
              point(
                Icons.delete_outline_rounded,
                'Deleting your data',
                'Disconnecting deletes your Strava data from LazyTax straight '
                    'away, and so does deleting your LazyTax account. To ask '
                    'for deletion any other way, email support@lazytax.club.',
              ),
            ],
          ),
        ),
        const GlassFooter(
          'Strava’s own terms and privacy policy apply to your Strava '
          'account.',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlassPill(
                label: 'Email support',
                icon: Icons.mail_outline_rounded,
                onTap: () => _open('mailto:support@lazytax.club'),
              ),
              GlassPill(
                label: 'Strava terms',
                icon: Icons.open_in_new_rounded,
                onTap: () => _open('https://www.strava.com/legal/terms'),
              ),
              GlassPill(
                label: 'Strava privacy',
                icon: Icons.open_in_new_rounded,
                onTap: () => _open('https://www.strava.com/legal/privacy'),
              ),
            ],
          ),
        ),
      ],
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
