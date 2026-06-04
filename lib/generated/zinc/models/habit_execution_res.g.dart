// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_execution_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HabitExecutionRes _$HabitExecutionResFromJson(Map<String, dynamic> json) =>
    HabitExecutionRes(
      id: json['id'] as String,
      habitVersionId: json['habitVersionId'] as String,
      paymentProcessed: json['paymentProcessed'] as bool,
      date: json['date'] as String?,
      status: json['status'] as String?,
      completedAt: json['completedAt'] as String?,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$HabitExecutionResToJson(HabitExecutionRes instance) =>
    <String, dynamic>{
      'id': instance.id,
      'habitVersionId': instance.habitVersionId,
      'date': instance.date,
      'status': instance.status,
      'completedAt': instance.completedAt,
      'notes': instance.notes,
      'paymentProcessed': instance.paymentProcessed,
    };
