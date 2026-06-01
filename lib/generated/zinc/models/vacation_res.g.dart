// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vacation_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VacationRes _$VacationResFromJson(Map<String, dynamic> json) => VacationRes(
  id: json['id'] as String,
  userId: json['userId'] as String?,
  startDate: json['startDate'] as String?,
  endDate: json['endDate'] as String?,
  timezone: json['timezone'] as String?,
  createdAt: json['createdAt'] as String?,
);

Map<String, dynamic> _$VacationResToJson(VacationRes instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'startDate': instance.startDate,
      'endDate': instance.endDate,
      'timezone': instance.timezone,
      'createdAt': instance.createdAt,
    };
