// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'user_principal_res.dart';

part 'user_res.g.dart';

@JsonSerializable()
class UserRes {
  const UserRes({required this.principal});

  factory UserRes.fromJson(Map<String, Object?> json) =>
      _$UserResFromJson(json);

  final UserPrincipalRes principal;

  Map<String, Object?> toJson() => _$UserResToJson(this);
}
