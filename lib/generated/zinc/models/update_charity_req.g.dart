// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_charity_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateCharityReq _$UpdateCharityReqFromJson(Map<String, dynamic> json) =>
    UpdateCharityReq(
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

Map<String, dynamic> _$UpdateCharityReqToJson(UpdateCharityReq instance) =>
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
