// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'subscription_res.g.dart';

@JsonSerializable()
class SubscriptionRes {
  const SubscriptionRes({
    required this.cancelAtPeriodEnd,
    this.userId,
    this.tier,
    this.status,
    this.periodStart,
    this.periodEnd,
    this.nextTier,
  });

  factory SubscriptionRes.fromJson(Map<String, Object?> json) =>
      _$SubscriptionResFromJson(json);

  final String? userId;
  final String? tier;
  final String? status;
  final String? periodStart;
  final String? periodEnd;
  final bool cancelAtPeriodEnd;
  final String? nextTier;

  Map<String, Object?> toJson() => _$SubscriptionResToJson(this);
}
