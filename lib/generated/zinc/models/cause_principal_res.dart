// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'cause_principal_res.g.dart';

@JsonSerializable()
class CausePrincipalRes {
  const CausePrincipalRes({this.id, this.key, this.name});

  factory CausePrincipalRes.fromJson(Map<String, Object?> json) =>
      _$CausePrincipalResFromJson(json);

  final String? id;
  final String? key;
  final String? name;

  Map<String, Object?> toJson() => _$CausePrincipalResToJson(this);
}
