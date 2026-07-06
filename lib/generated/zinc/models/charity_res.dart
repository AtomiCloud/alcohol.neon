// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'charity_principal_res.dart';

part 'charity_res.g.dart';

@JsonSerializable()
class CharityRes {
  const CharityRes({required this.principal});

  factory CharityRes.fromJson(Map<String, Object?> json) =>
      _$CharityResFromJson(json);

  final CharityPrincipalRes principal;

  Map<String, Object?> toJson() => _$CharityResToJson(this);
}
