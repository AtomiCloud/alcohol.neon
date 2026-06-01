// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'client_secret_res.g.dart';

@JsonSerializable()
class ClientSecretRes {
  const ClientSecretRes({
    this.clientSecret,
    this.customerId,
  });
  
  factory ClientSecretRes.fromJson(Map<String, Object?> json) => _$ClientSecretResFromJson(json);
  
  final String? clientSecret;
  final String? customerId;

  Map<String, Object?> toJson() => _$ClientSecretResToJson(this);
}
