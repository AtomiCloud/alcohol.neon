import '../core/problem.dart';
import '../generated/zinc/models/client_secret_res.dart';
import '../generated/zinc/models/confirm_payment_intent_req.dart';
import '../generated/zinc/models/confirm_payment_intent_res.dart';
import '../generated/zinc/models/create_customer_res.dart';
import '../generated/zinc/models/create_payment_intent_req.dart';
import '../generated/zinc/models/create_payment_intent_res.dart';
import '../generated/zinc/models/payment_consent_res.dart';
import '../networking/api_client.dart';

/// zinc `/Payment` endpoints — the Airwallex-backed customer, consent and
/// payment-intent flow. All routes are under `/{userId}/` and authenticated.
/// (The server-to-server webhook is intentionally not exposed here.)
class PaymentRepository {
  final ApiClient _api;
  PaymentRepository(this._api);

  static const _base = '/api/v1.0/Payment';

  /// Idempotently provisions the user's payment customer
  /// (`PUT /Payment/{userId}/customers`).
  Future<Result<CreateCustomerRes>> ensureCustomer(String userId) {
    return _api.put(
      '$_base/$userId/customers',
      null,
      (j) => CreateCustomerRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// A client secret for the user's customer, used to initialise the Airwallex
  /// SDK (`GET /Payment/{userId}/client-secret`).
  Future<Result<ClientSecretRes>> clientSecret(String userId) {
    return _api.get(
      '$_base/$userId/client-secret',
      (j) => ClientSecretRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// The user's current payment consent
  /// (`GET /Payment/{userId}/consent`).
  Future<Result<PaymentConsentRes>> consent(String userId) {
    return _api.get(
      '$_base/$userId/consent',
      (j) => PaymentConsentRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Revokes the user's payment consent
  /// (`DELETE /Payment/{userId}/consent`).
  Future<Result<void>> revokeConsent(String userId) {
    return _api.delete('$_base/$userId/consent');
  }

  /// Creates a payment intent for the user
  /// (`POST /Payment/{userId}/intent`).
  Future<Result<CreatePaymentIntentRes>> createIntent(
    String userId,
    CreatePaymentIntentReq req,
  ) {
    return _api.post(
      '$_base/$userId/intent',
      req.toJson(),
      (j) => CreatePaymentIntentRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Confirms an existing payment intent
  /// (`POST /Payment/{userId}/intent/{intentId}`).
  Future<Result<ConfirmPaymentIntentRes>> confirmIntent(
    String userId,
    String intentId,
    ConfirmPaymentIntentReq req,
  ) {
    return _api.post(
      '$_base/$userId/intent/$intentId',
      req.toJson(),
      (j) => ConfirmPaymentIntentRes.fromJson(j as Map<String, Object?>),
    );
  }
}
