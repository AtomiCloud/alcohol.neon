// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_vacation_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateVacationReq _$CreateVacationReqFromJson(Map<String, dynamic> json) =>
    CreateVacationReq(
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      timezone: json['timezone'] as String?,
    );

Map<String, dynamic> _$CreateVacationReqToJson(CreateVacationReq instance) =>
    <String, dynamic>{
      'startDate': instance.startDate,
      'endDate': instance.endDate,
      'timezone': instance.timezone,
    };
