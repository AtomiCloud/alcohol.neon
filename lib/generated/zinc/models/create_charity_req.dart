// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_charity_req.g.dart';

@JsonSerializable()
class CreateCharityReq {
  const CreateCharityReq({
    this.name,
    this.slug,
    this.mission,
    this.countries,
    this.primaryRegistrationNumber,
    this.primaryRegistrationCountry,
    this.websiteUrl,
    this.logoUrl,
  });
  
  factory CreateCharityReq.fromJson(Map<String, Object?> json) => _$CreateCharityReqFromJson(json);
  
  final String? name;
  final String? slug;
  final String? mission;
  final List<String>? countries;
  final String? primaryRegistrationNumber;
  final String? primaryRegistrationCountry;
  final String? websiteUrl;
  final String? logoUrl;

  Map<String, Object?> toJson() => _$CreateCharityReqToJson(this);
}
