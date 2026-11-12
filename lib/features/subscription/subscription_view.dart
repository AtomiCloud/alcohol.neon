import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../generated/zinc/models/plan_res.dart';
import '../../services/storefront_service.dart';
import '../../session/session_controller.dart';
import '../../theme/glass.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_page.dart';
import 'subscription_controller.dart';
import 'tier.dart';

/// Subscription screen. What it may say is decided by zinc per platform +
/// storefront (App Store steering rules):
///   * manage    — subscribed users, everywhere: link out to the web portal
///   * subscribe — free users where link-out is permitted (e.g. US/EU)
///   * neutral   — restricted storefronts: plan info only. NO store button,
///                 NO "cheaper on the web" copy, NO comparison with other
///                 plans — that text in-app is a steering violation there.
///
/// The page shows the plan, what it includes (limits from
/// `GET /Subscription/plans`), on the subscribe variant what the next plan
/// adds, and the web button in the bottom bar.
class SubscriptionView extends StatefulWidget {
  /// Test seam: when provided, the view renders this controller as-is (no
  /// session lookup, no load, no dispose ownership).
  @visibleForTesting
  final SubscriptionController? controller;

  const SubscriptionView({super.key, this.controller});

  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView>
    with WidgetsBindingObserver {
  SubscriptionController? _controller;
  bool _owned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
      return;
    }
    final session = context.read<SessionController>();
    final userId = session.userId;
    if (userId != null) {
      _owned = true;
      _controller = SubscriptionController(
        repository: session.subscriptions,
        storefront: StoreStorefrontService(),
        userId: userId,
      )..load();
    }
  }

  /// Subscribing/managing happens in the external browser; when the app comes
  /// back to the foreground, re-ask zinc so a new subscription shows up
  /// immediately instead of a stale "Free plan".
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller?.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_owned) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const GlassPage(
        title: 'Subscription',
        children: [
          Padding(
            padding: EdgeInsets.only(top: 48),
            child: Text(
              'Sign in to manage your subscription',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => GlassPage(
        title: 'Subscription',
        dock: controller.loading || controller.error != null
            ? null
            : _dock(context, controller),
        children: _body(context, controller),
      ),
    );
  }

  List<Widget> _body(BuildContext context, SubscriptionController c) {
    if (c.loading) return const [SizedBox(height: 320, child: AppLoader())];
    final error = c.error;
    if (error != null) {
      return [
        GlassBanner(
          icon: Icons.cloud_off_rounded,
          title: error.title,
          body: error.detail,
          error: true,
          action: GlassTextButton(label: 'Retry', onPressed: c.load),
        ),
      ];
    }
    final name = tierLabel(c.tier ?? '');
    final plan = c.plan;
    final next = c.variant == SubscriptionCtaVariant.subscribe
        ? c.nextPlan
        : null;
    final adds = next == null || plan == null
        ? const <String>[]
        : _adds(plan, next);
    return [
      if (c.openError case final openError?)
        GlassBanner(
          icon: Icons.error_outline_rounded,
          title: openError.title,
          body: openError.detail,
          error: true,
        ),
      const SizedBox(height: 4),
      _PlanCard(name: name.isEmpty ? 'Unknown' : name, paid: _paid(c.tier)),
      if (plan != null)
        GlassSection(
          title: '${name.isEmpty ? 'Your plan' : name} includes',
          dividerIndent: 52,
          children: [for (final p in _perks(plan)) _Perk(p)],
        ),
      if (adds.isNotEmpty)
        GlassSection(
          title: '${tierLabel(next!.key ?? '')} adds',
          dividerIndent: 52,
          children: [for (final p in adds) _Perk(p, accent: true)],
        ),
    ];
  }

  bool _paid(String? tier) => tier != null && tier.isNotEmpty && tier != 'free';

  /// The bottom bar: one web button, or nothing in restricted storefronts.
  Widget? _dock(BuildContext context, SubscriptionController c) {
    final label = switch (c.variant) {
      SubscriptionCtaVariant.manage => 'Manage subscription',
      SubscriptionCtaVariant.subscribe => 'Subscribe on the web',
      // Neutral: no action, no steering copy — plan info only.
      SubscriptionCtaVariant.neutral => null,
    };
    if (label == null) return null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Opens in your browser',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: GlassTokens.of(context).muted),
        ),
        const SizedBox(height: 8),
        GlassButton(label: label, busy: c.opening, onPressed: c.openPortal),
      ],
    );
  }
}

/// One line per limit of [p], in the words Today uses.
List<String> _perks(PlanRes p) => [
  p.habitsUnlimited
      ? 'Unlimited habits'
      : 'Up to ${p.habitsMax ?? 0} habit${p.habitsMax == 1 ? '' : 's'}',
  '${p.skipsMonthly} skip${p.skipsMonthly == 1 ? '' : 's'} each month',
  p.vacationWindowsYearly == 0
      ? 'No vacations'
      : '${p.vacationWindowsYearly} vacation${p.vacationWindowsYearly == 1 ? '' : 's'} each year',
];

/// The lines of [next] that are better than [current].
List<String> _adds(PlanRes current, PlanRes next) {
  final a = _perks(current), b = _perks(next);
  return [
    for (var i = 0; i < b.length; i++)
      if (a[i] != b[i]) b[i],
  ];
}

class _PlanCard extends StatelessWidget {
  final String name;
  final bool paid;
  const _PlanCard({required this.name, required this.paid});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    return Glass(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: paid ? const Color(0xFFF59E0B) : const Color(0xFF71717A),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const SizedBox.square(
              dimension: 44,
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your plan',
                  style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
                ),
                Text(
                  '$name plan',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  final String text;
  final bool accent;
  const _Perk(this.text, {this.accent = false});

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return GlassRow(
      leading: Icon(
        accent ? Icons.add_circle_outline_rounded : Icons.check_rounded,
        color: t.accent,
      ),
      title: text,
    );
  }
}
