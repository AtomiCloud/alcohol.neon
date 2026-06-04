// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'award_weekly_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AwardWeeklyRes _$AwardWeeklyResFromJson(Map<String, dynamic> json) =>
    AwardWeeklyRes(
      awards: (json['awards'] as num).toInt(),
      userId: json['userId'] as String?,
    );

Map<String, dynamic> _$AwardWeeklyResToJson(AwardWeeklyRes instance) =>
    <String, dynamic>{'userId': instance.userId, 'awards': instance.awards};
