// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nfc_tag_resolution_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NfcTagResolutionRes _$NfcTagResolutionResFromJson(Map<String, dynamic> json) =>
    NfcTagResolutionRes(
      tag: NfcTagRes.fromJson(json['tag'] as Map<String, dynamic>),
      habitVersion: HabitVersionRes.fromJson(
        json['habitVersion'] as Map<String, dynamic>,
      ),
      todayExecution: HabitExecutionRes.fromJson(
        json['todayExecution'] as Map<String, dynamic>,
      ),
      today: json['today'] as String?,
    );

Map<String, dynamic> _$NfcTagResolutionResToJson(
  NfcTagResolutionRes instance,
) => <String, dynamic>{
  'tag': instance.tag,
  'habitVersion': instance.habitVersion,
  'today': instance.today,
  'todayExecution': instance.todayExecution,
};
