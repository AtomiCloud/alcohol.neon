// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'user_principal_res.g.dart';

@JsonSerializable()
class UserPrincipalRes {
  const UserPrincipalRes({
    required this.emailVerified,
    required this.active,
    this.id,
    this.username,
    this.email,
  });
  
  factory UserPrincipalRes.fromJson(Map<String, Object?> json) => _$UserPrincipalResFromJson(json);
  
  final String? id;
  final String? username;
  final String? email;
  final bool emailVerified;
  final bool active;

  Map<String, Object?> toJson() => _$UserPrincipalResToJson(this);
}
