import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/problem.dart';
import '../../services/storefront_service.dart';
import '../../session/session_controller.dart';
import '../../widgets/app_loader.dart';
import 'subscription_controller.dart';

/// Subscription screen. What it may say is decided by zinc per platform +
/// storefront (App Store steering rules):
///   * manage    — subscribed users, everywhere: link out to the web portal
///   * subscribe — free users where link-out is permitted (e.g. US/EU)
///   * neutral   — restricted storefronts: plan info only. NO store button,
///                 NO "cheaper on the web" copy, NO price comparison — that
///                 text in-app is a steering violation in those regions.
class SubscriptionView extends StatefulWidget {
  const SubscriptionView({super.key});

  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView> {
  SubscriptionController? _controller;

  @override
  void initState() {
    super.initState();
    final session = context.read<SessionController>();
    final userId = session.userId;
    if (userId != null) {
      _controller = SubscriptionController(
        repository: session.subscriptions,
        storefront: StoreStorefrontService(),
        userId: userId,
      )..load();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: controller == null
          ? const Center(child: Text('Sign in to manage your subscription'))
          : ListenableBuilder(
              listenable: controller,
              builder: (context, _) => _body(context, controller),
            ),
    );
  }

  Widget _body(BuildContext context, SubscriptionController c) {
    if (c.loading) return const AppLoader();
    final error = c.error;
    if (error != null) {
      return _ErrorRetry(problem: error, onRetry: c.load);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PlanCard(tier: c.tier),
        const SizedBox(height: 16),
        ..._cta(context, c),
        if (c.openError != null) ...[
          const SizedBox(height: 12),
          Text(
            c.openError!.detail ?? c.openError!.title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _cta(BuildContext context, SubscriptionController c) {
    final button = switch (c.variant) {
      SubscriptionCtaVariant.manage => FilledButton.icon(
        onPressed: c.opening ? null : c.openPortal,
        icon: const Icon(Icons.open_in_browser),
        label: c.opening
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Manage subscription'),
      ),
      SubscriptionCtaVariant.subscribe => FilledButton.icon(
        onPressed: c.opening ? null : c.openPortal,
        icon: const Icon(Icons.open_in_browser),
        label: c.opening
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Subscribe on the web'),
      ),
      // Neutral: no action, no steering copy — plan info only.
      SubscriptionCtaVariant.neutral => null,
    };
    if (button == null) return const [];
    return [
      button,
      const SizedBox(height: 8),
      Text(
        'Opens in your browser.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ];
  }
}

class _PlanCard extends StatelessWidget {
  final String? tier;
  const _PlanCard({required this.tier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = tier;
    final name = t == null || t.isEmpty
        ? 'Unknown'
        : '${t[0].toUpperCase()}${t.substring(1)}';
    final isFree = t == null || t == 'free';
    return Card(
      child: ListTile(
        leading: Icon(
          isFree ? Icons.workspace_premium_outlined : Icons.workspace_premium,
          color: isFree ? theme.colorScheme.onSurfaceVariant : Colors.amber,
        ),
        title: Text('$name plan'),
        subtitle: Text(
          isFree
              ? 'You are on the free plan.'
              : 'Your plan renews automatically.',
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final Problem problem;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.problem, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(problem.title, style: Theme.of(context).textTheme.titleMedium),
            if (problem.detail != null) ...[
              const SizedBox(height: 8),
              Text(problem.detail!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
