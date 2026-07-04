import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import '../core/iso3166.dart';

/// The caller's app-store identity: which platform build this is and which
/// storefront country the store account belongs to. zinc's CTA matrix keys the
/// steering rules off this, so accuracy matters more than the device locale
/// (the store region is the legally relevant one).
class StorefrontInfo {
  /// 'ios' or 'android' — the values zinc's web-handoff validator accepts.
  final String platform;

  /// ISO 3166-1 alpha-2 storefront country, or null when it could not be
  /// determined (zinc fails closed to the neutral CTA in that case).
  final String? countryCode;

  const StorefrontInfo({required this.platform, this.countryCode});
}

/// Seam for storefront resolution so screens/tests can fake it.
abstract class StorefrontService {
  Future<StorefrontInfo> resolve();
}

/// Real-store implementation: StoreKit storefront on iOS (alpha-3, mapped to
/// alpha-2), Play Billing config country on Android. Any failure or timeout
/// falls back to the OS locale region — an approximation, but zinc re-checks
/// the rules server-side and unknown storefronts fail closed anyway.
class StoreStorefrontService implements StorefrontService {
  static const _storeTimeout = Duration(seconds: 2);
  static bool _androidRegistered = false;

  @override
  Future<StorefrontInfo> resolve() async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    String? country;
    try {
      country = await (Platform.isIOS ? _iosCountry() : _androidCountry())
          .timeout(_storeTimeout);
    } catch (_) {
      country = null;
    }
    country ??= PlatformDispatcher.instance.locale.countryCode;
    if (country != null && country.length != 2) country = null;
    return StorefrontInfo(
      platform: platform,
      countryCode: country?.toUpperCase(),
    );
  }

  /// StoreKit reports the storefront as ISO 3166-1 **alpha-3**; zinc wants
  /// alpha-2, so map it (null when Apple returns something unmapped).
  Future<String?> _iosCountry() async {
    final storefront = await SKPaymentQueueWrapper().storefront();
    final alpha3 = storefront?.countryCode;
    if (alpha3 == null) return null;
    return iso3166Alpha3ToAlpha2[alpha3.toUpperCase()];
  }

  /// Play Billing's billing-config country (ISO 3166-1 alpha-2 already).
  Future<String?> _androidCountry() async {
    if (!_androidRegistered) {
      InAppPurchaseAndroidPlatform.registerPlatform();
      _androidRegistered = true;
    }
    return InAppPurchasePlatform.instance.countryCode();
  }
}
