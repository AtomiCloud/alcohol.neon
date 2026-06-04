// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_charity_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCharityReq _$CreateCharityReqFromJson(Map<String, dynamic> json) =>
    CreateCharityReq(
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

Map<String, dynamic> _$CreateCharityReqToJson(CreateCharityReq instance) =>
    <String, dynamic>{
      'name': instance.name,
      'slug': instance.slug,
      'mission': instance.mission,
      'countries': instance.countries,
      'primaryRegistrationNumber': instance.primaryRegistrationNumber,
      'primaryRegistrationCountry': instance.primaryRegistrationCountry,
      'websiteUrl': instance.websiteUrl,
      'logoUrl': instance.logoUrl,
    };
