// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nfc_tag_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NfcTagRes _$NfcTagResFromJson(Map<String, dynamic> json) => NfcTagRes(
  habitId: json['habitId'] as String,
  id: json['id'] as String?,
  userId: json['userId'] as String?,
  claimedAt: json['claimedAt'] as String?,
);

Map<String, dynamic> _$NfcTagResToJson(NfcTagRes instance) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'habitId': instance.habitId,
  'claimedAt': instance.claimedAt,
};
