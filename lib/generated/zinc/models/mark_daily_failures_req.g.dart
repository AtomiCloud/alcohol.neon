// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mark_daily_failures_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MarkDailyFailuresReq _$MarkDailyFailuresReqFromJson(
  Map<String, dynamic> json,
) => MarkDailyFailuresReq(
  date: json['date'] as String?,
  habitIds: (json['habitIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$MarkDailyFailuresReqToJson(
  MarkDailyFailuresReq instance,
) => <String, dynamic>{'date': instance.date, 'habitIds': instance.habitIds};
