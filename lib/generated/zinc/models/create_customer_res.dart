// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_customer_res.g.dart';

@JsonSerializable()
class CreateCustomerRes {
  const CreateCustomerRes({this.customerId, this.clientSecret});

  factory CreateCustomerRes.fromJson(Map<String, Object?> json) =>
      _$CreateCustomerResFromJson(json);

  final String? customerId;
  final String? clientSecret;

  Map<String, Object?> toJson() => _$CreateCustomerResToJson(this);
}
