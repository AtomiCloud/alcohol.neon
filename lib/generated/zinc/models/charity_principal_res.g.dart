// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'charity_principal_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CharityPrincipalRes _$CharityPrincipalResFromJson(Map<String, dynamic> json) =>
    CharityPrincipalRes(
      id: json['id'] as String?,
      name: json['name'] as String?,
      slug: json['slug'] as String?,
      mission: json['mission'] as String?,
      countries: (json['countries'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      primaryRegistrationNumber: json['primaryRegistrationNumber'] as String?,
      primaryRegistrationCountry: json['primaryRegistrationCountry'] as String?,
      websiteUrl: json['websiteUrl'] as String?,
      logoUrl: json['logoUrl'] as String?,
    );

Map<String, dynamic> _$CharityPrincipalResToJson(
  CharityPrincipalRes instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'slug': instance.slug,
  'mission': instance.mission,
  'countries': instance.countries,
  'primaryRegistrationNumber': instance.primaryRegistrationNumber,
  'primaryRegistrationCountry': instance.primaryRegistrationCountry,
  'websiteUrl': instance.websiteUrl,
  'logoUrl': instance.logoUrl,
};
