import 'package:airwallex_payment_flutter/airwallex.dart';
import 'package:airwallex_payment_flutter/types/environment.dart';
import 'package:airwallex_payment_flutter/types/merchant_trigger_reason.dart';
import 'package:airwallex_payment_flutter/types/next_triggered_by.dart';
import 'package:airwallex_payment_flutter/types/payment_result.dart';
import 'package:airwallex_payment_flutter/types/payment_session.dart';
import 'package:flutter/services.dart';

import '../../core/problem.dart';

/// Outcome of presenting the native card-on-file consent sheet. Mirrors the
/// SDK's [PaymentResult] subtypes (success / cancelled / in-progress) plus a
/// boundary-failure case so widgets never see a thrown exception.
enum ConsentCollectOutcome {
  /// The card sheet completed and the SDK reported success. The actual consent
  /// record is confirmed server-side by polling `GET /Payment/{userId}/consent`.
  success,

  /// The user dismissed the sheet without finishing.
  cancelled,

  /// The SDK reported the flow is still in progress (e.g. a redirect-based method
  /// that hasn't resolved). Treated like "keep polling" by the orchestrator.
  inProgress,

  /// The collector itself failed (SDK/native error, missing customerId/secret).
  failed,
}

/// The result of a consent collection attempt. Carries the optional
/// `paymentConsentId` the SDK surfaces on success, and a [Problem] on failure.
class ConsentCollectResult {
  final ConsentCollectOutcome outcome;
  final String? paymentConsentId;
  final Problem? problem;

  const ConsentCollectResult._(this.outcome, {this.paymentConsentId, this.problem});

  factory ConsentCollectResult.success({String? paymentConsentId}) =>
      ConsentCollectResult._(ConsentCollectOutcome.success,
          paymentConsentId: paymentConsentId);

  factory ConsentCollectResult.cancelled() =>
      const ConsentCollectResult._(ConsentCollectOutcome.cancelled);

  factory ConsentCollectResult.inProgress() =>
      const ConsentCollectResult._(ConsentCollectOutcome.inProgress);

  factory ConsentCollectResult.failed(Problem problem) =>
      ConsentCollectResult._(ConsentCollectOutcome.failed, problem: problem);

  bool get isSuccess => outcome == ConsentCollectOutcome.success;
  bool get isCancelled => outcome == ConsentCollectOutcome.cancelled;
  bool get isInProgress => outcome == ConsentCollectOutcome.inProgress;
  bool get isFailed => outcome == ConsentCollectOutcome.failed;
}

/// Collects a recurring, merchant-initiated, card-on-file payment consent from
/// the user. Abstracted so an alternative (e.g. a web/HPP) flow can swap in later
/// without touching the orchestration in `consent_service.dart`.
abstract class PaymentConsentCollector {
  /// Presents the consent UI for the given Airwallex [customerId] + [clientSecret]
  /// (both from `PUT /Payment/{userId}/customers` or `GET .../client-secret`).
  /// Never throws — failures come back as [ConsentCollectResult.failed].
  Future<ConsentCollectResult> collect({
    required String? customerId,
    required String? clientSecret,
  });
}

/// Native-SDK implementation using `airwallex_payment_flutter`.
///
/// Builds a [RecurringSession] (type `'Recurring'`) configured for a
/// merchant-initiated, **unscheduled**, USD card-on-file mandate
/// (`nextTriggeredBy: merchant`, `merchantTriggerReason: unscheduled`,
/// `currency: 'USD'`) — matching argon's `redirectToCheckout` recurringOptions —
/// and presents the native card sheet via `presentCardPaymentFlow`. We use the
/// card-only flow (not the full payment-method flow) because this is purely about
/// capturing a card-on-file mandate; there is no one-off intent to pay.
class AirwallexConsentCollector implements PaymentConsentCollector {
  final Environment environment;

  /// Country the mandate is registered under. Argon's web flow doesn't send a
  /// country (the HPP infers it); the native session requires one, and the
  /// product charges in USD, so 'US' is the natural default.
  final String countryCode;

  /// Whether the SDK has been initialised this process. The SDK's `initialize`
  /// is a static, idempotent-ish call; we guard so we only configure once per
  /// environment.
  static Environment? _initializedFor;

  AirwallexConsentCollector({
    required this.environment,
    this.countryCode = 'US',
  });

  void _ensureInitialized() {
    if (_initializedFor == environment) return;
    Airwallex.initialize(environment: environment);
    _initializedFor = environment;
  }

  @override
  Future<ConsentCollectResult> collect({
    required String? customerId,
    required String? clientSecret,
  }) async {
    // customerId / clientSecret are nullable in the generated DTOs — a recurring
    // card-on-file mandate is meaningless without both.
    if (customerId == null || customerId.isEmpty) {
      return ConsentCollectResult.failed(Problem.local(
        'Could not start payment setup',
        type: 'neon:payment',
        detail: 'Missing customer id from the payment service.',
      ));
    }
    if (clientSecret == null || clientSecret.isEmpty) {
      return ConsentCollectResult.failed(Problem.local(
        'Could not start payment setup',
        type: 'neon:payment',
        detail: 'Missing client secret from the payment service.',
      ));
    }

    try {
      _ensureInitialized();

      final session = RecurringSession(
        customerId: customerId,
        clientSecret: clientSecret,
        currency: 'USD',
        countryCode: countryCode,
        // No charge now — this only captures a card-on-file mandate. 0 keeps the
        // sheet's copy at "save card" rather than a payable amount.
        amount: 0,
        isBillingRequired: true,
        isEmailRequired: false,
        nextTriggeredBy: NextTriggeredBy.merchant,
        merchantTriggerReason: MerchantTriggerReason.unscheduled,
      );

      final PaymentResult result =
          await Airwallex().presentCardPaymentFlow(session);

      switch (result) {
        case PaymentSuccessResult(:final paymentConsentId):
          return ConsentCollectResult.success(
              paymentConsentId: paymentConsentId);
        case PaymentCancelledResult():
          return ConsentCollectResult.cancelled();
        case PaymentInProgressResult():
          return ConsentCollectResult.inProgress();
        default:
          return ConsentCollectResult.failed(Problem.local(
            'Payment setup did not complete',
            type: 'neon:payment',
            detail: 'Unexpected payment result: ${result.status}.',
          ));
      }
    } on PlatformException catch (e) {
      return ConsentCollectResult.failed(Problem.local(
        'Payment setup failed',
        type: 'neon:payment',
        detail: e.message ?? e.toString(),
      ));
    } catch (e) {
      return ConsentCollectResult.failed(Problem.local(
        'Payment setup failed',
        type: 'neon:payment',
        detail: e.toString(),
      ));
    }
  }
}
