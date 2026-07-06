// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'subscription_cta_res.g.dart';

@JsonSerializable()
class SubscriptionCtaRes {
  const SubscriptionCtaRes({this.variant, this.tier});

  factory SubscriptionCtaRes.fromJson(Map<String, Object?> json) =>
      _$SubscriptionCtaResFromJson(json);

  final String? variant;
  final String? tier;

  Map<String, Object?> toJson() => _$SubscriptionCtaResToJson(this);
}
