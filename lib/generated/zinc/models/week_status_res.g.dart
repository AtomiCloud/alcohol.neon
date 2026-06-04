// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'week_status_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeekStatusRes _$WeekStatusResFromJson(Map<String, dynamic> json) =>
    WeekStatusRes(
      sunday: json['sunday'] as String?,
      monday: json['monday'] as String?,
      tuesday: json['tuesday'] as String?,
      wednesday: json['wednesday'] as String?,
      thursday: json['thursday'] as String?,
      friday: json['friday'] as String?,
      saturday: json['saturday'] as String?,
      start: json['start'] as String?,
      end: json['end'] as String?,
    );

Map<String, dynamic> _$WeekStatusResToJson(WeekStatusRes instance) =>
    <String, dynamic>{
      'sunday': instance.sunday,
      'monday': instance.monday,
      'tuesday': instance.tuesday,
      'wednesday': instance.wednesday,
      'thursday': instance.thursday,
      'friday': instance.friday,
      'saturday': instance.saturday,
      'start': instance.start,
      'end': instance.end,
    };
