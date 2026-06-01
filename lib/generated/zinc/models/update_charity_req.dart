// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_charity_req.g.dart';

@JsonSerializable()
class UpdateCharityReq {
  const UpdateCharityReq({
    this.name,
    this.slug,
    this.mission,
    this.countries,
    this.primaryRegistrationNumber,
    this.primaryRegistrationCountry,
    this.websiteUrl,
    this.logoUrl,
  });
  
  factory UpdateCharityReq.fromJson(Map<String, Object?> json) => _$UpdateCharityReqFromJson(json);
  
  final String? name;
  final String? slug;
  final String? mission;
  final List<String>? countries;
  final String? primaryRegistrationNumber;
  final String? primaryRegistrationCountry;
  final String? websiteUrl;
  final String? logoUrl;

  Map<String, Object?> toJson() => _$UpdateCharityReqToJson(this);
}
