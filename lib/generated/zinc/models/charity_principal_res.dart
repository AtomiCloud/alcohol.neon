// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'charity_principal_res.g.dart';

@JsonSerializable()
class CharityPrincipalRes {
  const CharityPrincipalRes({
    this.id,
    this.name,
    this.slug,
    this.mission,
    this.countries,
    this.primaryRegistrationNumber,
    this.primaryRegistrationCountry,
    this.websiteUrl,
    this.logoUrl,
  });
  
  factory CharityPrincipalRes.fromJson(Map<String, Object?> json) => _$CharityPrincipalResFromJson(json);
  
  final String? id;
  final String? name;
  final String? slug;
  final String? mission;
  final List<String>? countries;
  final String? primaryRegistrationNumber;
  final String? primaryRegistrationCountry;
  final String? websiteUrl;
  final String? logoUrl;

  Map<String, Object?> toJson() => _$CharityPrincipalResToJson(this);
}
