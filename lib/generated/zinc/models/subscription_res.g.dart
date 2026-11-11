// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SubscriptionRes _$SubscriptionResFromJson(Map<String, dynamic> json) =>
    SubscriptionRes(
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] as bool,
      userId: json['userId'] as String?,
      tier: json['tier'] as String?,
      status: json['status'] as String?,
      periodStart: json['periodStart'] as String?,
      periodEnd: json['periodEnd'] as String?,
      nextTier: json['nextTier'] as String?,
    );

Map<String, dynamic> _$SubscriptionResToJson(SubscriptionRes instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'tier': instance.tier,
      'status': instance.status,
      'periodStart': instance.periodStart,
      'periodEnd': instance.periodEnd,
      'cancelAtPeriodEnd': instance.cancelAtPeriodEnd,
      'nextTier': instance.nextTier,
    };
