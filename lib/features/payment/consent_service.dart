import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/problem.dart';
import '../../session/session_controller.dart';
import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import 'payment_consent_collector.dart';

/// Orchestrates the end-to-end payment-consent collection (plan M6):
///
/// 1. Short-circuit if the session already has consent.
/// 2. Provision the Airwallex customer (`PUT /Payment/{userId}/customers`) to get
///    a `customerId` + `clientSecret` (falling back to `GET .../client-secret`).
/// 3. Explain the card in a glass sheet (argon's `ConsentConfirmModal`).
/// 4. Present the native card sheet via the [PaymentConsentCollector].
/// 5. On a successful sheet, **poll** `GET /Payment/{userId}/consent` on argon's
///    exact schedule (5×1000ms, then `min(interval*2, 30000)`, total cap 120000ms,
///    tolerating transient GET failures, success when `hasPaymentConsent`) behind a
///    "don't leave this screen" overlay.
/// 6. On confirmed consent, refresh the session cache.
///
/// Returns a [Result] — `Ok(())` when consent is in place, `Err(Problem)` with the
/// reason otherwise (cancelled, timed out, or a service failure). Never throws.
class ConsentService {
  final SessionController session;

  /// Factory for the collector, so tests / a future web flow can inject one.
  /// Defaults to the native Airwallex collector configured from [AppConfig].
  final PaymentConsentCollector Function() collectorFactory;

  ConsentService(
    this.session, {
    PaymentConsentCollector Function()? collectorFactory,
  }) : collectorFactory =
           collectorFactory ??
           (() => AirwallexConsentCollector(
             environment: AppConfig.current.airwallexEnv,
           ));

  // Polling schedule — copied verbatim from argon's `pollPaymentConsent`.
  static const _maxDuration = Duration(milliseconds: 120000);
  static const _initialAttempts = 5;
  static const _initialInterval = Duration(milliseconds: 1000);
  static const _maxInterval = Duration(milliseconds: 30000);

  /// Cancelled by the user from the confirm dialog.
  static final _cancelled = Problem.local(
    'Payment setup cancelled',
    type: 'neon:payment',
    detail: 'You can set up a payment method later from Settings.',
  );

  /// Ensures the user has a payment consent, collecting one if needed.
  ///
  /// [context] must be mounted; it's used to show the confirm dialog and the
  /// blocking poll overlay. Safe to call when consent already exists (returns
  /// `Ok` immediately).
  Future<Result<void>> ensureConsent(BuildContext context) async {
    if (session.hasPaymentConsent) return const Ok(null);

    final userId = session.userId;
    if (userId == null) return const Err(Problem.unauthenticated);

    // 1. Provision customer (idempotent) → customerId + clientSecret.
    String? customerId;
    String? clientSecret;

    final customerRes = await session.payments.ensureCustomer(userId);
    switch (customerRes) {
      case Ok(:final value):
        customerId = value.customerId;
        clientSecret = value.clientSecret;
      case Err(:final problem):
        return Err(problem);
    }

    // Fall back to the dedicated client-secret endpoint if the customer call
    // didn't return one (both fields are nullable in the generated DTO).
    if (clientSecret == null || clientSecret.isEmpty) {
      final secretRes = await session.payments.clientSecret(userId);
      switch (secretRes) {
        case Ok(:final value):
          clientSecret = value.clientSecret;
          customerId ??= value.customerId;
        case Err(:final problem):
          return Err(problem);
      }
    }

    if (!context.mounted) return const Err(Problem.unauthenticated);

    // 2. Pre-launch confirm (mirrors argon's ConsentConfirmModal copy).
    final confirmed = await _showConfirmDialog(context);
    if (confirmed != true) return Err(_cancelled);
    if (!context.mounted) return const Err(Problem.unauthenticated);

    // 3. Present the native card sheet.
    final collector = collectorFactory();
    final collect = await collector.collect(
      customerId: customerId,
      clientSecret: clientSecret,
    );

    if (collect.isCancelled) return Err(_cancelled);
    if (collect.isFailed) {
      return Err(
        collect.problem ??
            Problem.local('Payment setup failed', type: 'neon:payment'),
      );
    }
    // success or inProgress → poll the server for the consent record.

    if (!context.mounted) return const Err(Problem.unauthenticated);

    // 4. Poll behind a blocking overlay.
    return _pollWithOverlay(context, userId);
  }

  /// What adding a card means, in a glass sheet: when it's charged, who
  /// holds it, how to remove it. Continue returns true.
  Future<bool?> _showConfirmDialog(BuildContext context) =>
      showGlassSheet<bool>(context, (ctx) => const ConsentExplainer());

  /// Shows a non-dismissible overlay, runs [_poll], then tears the overlay down.
  Future<Result<void>> _pollWithOverlay(
    BuildContext context,
    String userId,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);

    // Push a blocking overlay route — back-button disabled, no dismiss.
    unawaited(navigator.push(_PollOverlayRoute()));

    final result = await _poll(userId);

    // Tear down the overlay if it's still up.
    if (navigator.canPop()) navigator.pop();

    if (result case Ok()) {
      // Refresh the session cache so gates + the settings card update.
      await session.refreshConsent();
    }
    return result;
  }

  /// Polls `GET /Payment/{userId}/consent` on argon's schedule until consent is
  /// confirmed or the total duration cap elapses. Transient GET failures are
  /// swallowed (we keep polling) — only the timeout is surfaced as an error.
  Future<Result<void>> _poll(String userId) async {
    final start = DateTime.now();
    var attempts = 0;
    var interval = _initialInterval;

    while (true) {
      attempts++;

      final res = await session.payments.consent(userId);
      if (res case Ok(:final value) when value.hasPaymentConsent) {
        return const Ok(null);
      }
      // Any non-success (or consent not yet present) → keep polling within cap.

      final elapsed = DateTime.now().difference(start);
      if (elapsed >= _maxDuration) {
        return Err(
          Problem.local(
            'Payment setup is taking longer than expected',
            type: 'neon:payment',
            detail:
                "We couldn't confirm your payment method in time. If you "
                'completed the card form, check Settings in a moment.',
          ),
        );
      }

      if (attempts >= _initialAttempts) {
        final doubled = interval * 2;
        interval = doubled > _maxInterval ? _maxInterval : doubled;
      }

      // Don't overshoot the cap on the final wait.
      final remaining = _maxDuration - elapsed;
      await Future<void>.delayed(interval < remaining ? interval : remaining);
    }
  }
}

/// A non-dismissible full-screen overlay shown while polling for the consent
/// record. Blocks the back button so the user can't navigate away mid-confirm.
class _PollOverlayRoute extends ModalRoute<void> {
  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // PopScope blocks the system back gesture/button.
    return const PopScope(canPop: false, child: ConsentConfirming());
  }
}

/// The sheet before Airwallex's card form.
class ConsentExplainer extends StatelessWidget {
  const ConsentExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    Widget point(IconData icon, String title, String body, {Color? color}) =>
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: color ?? t.muted),
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
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: t.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.track,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(
                  dimension: 48,
                  child: Icon(Icons.credit_card_rounded, size: 24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a card to stake',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'A money stake needs a card on file. You add it with our '
              'payment partner Airwallex.',
              style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
            ),
            point(
              Icons.payments_outlined,
              'Charged only when you miss',
              'Your stake goes to your charity for each missed day. Nothing '
                  'is charged now.',
              color: t.accent,
            ),
            point(
              Icons.shield_outlined,
              'Kept by Airwallex',
              'Airwallex holds your card details securely. LazyTax never '
                  'sees them.',
            ),
            point(
              Icons.delete_outline_rounded,
              'Remove it any time',
              'In Settings. Staked habits stop charging until you add a '
                  'card again.',
            ),
            const SizedBox(height: 24),
            GlassButton(
              label: 'Continue',
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: t.muted),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The glass card shown while zinc confirms the new card.
class ConsentConfirming extends StatelessWidget {
  const ConsentConfirming({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Glass(
          blur: true,
          strong: true,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: t.accent,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Confirming your card…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please stay on this screen. This can take up to two '
                  'minutes.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
