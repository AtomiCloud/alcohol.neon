// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'cause_principal_res.dart';

part 'cause_res.g.dart';

@JsonSerializable()
class CauseRes {
  const CauseRes({required this.principal});

  factory CauseRes.fromJson(Map<String, Object?> json) =>
      _$CauseResFromJson(json);

  final CausePrincipalRes principal;

  Map<String, Object?> toJson() => _$CauseResToJson(this);
}
