// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_notification_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InboxNotificationRes _$InboxNotificationResFromJson(
  Map<String, dynamic> json,
) => InboxNotificationRes(
  id: json['id'] as String,
  createdAtUtc: DateTime.parse(json['createdAtUtc'] as String),
  kind: json['kind'] as String?,
  title: json['title'] as String?,
  body: json['body'] as String?,
  actorUserId: json['actorUserId'] as String?,
  data: json['data'] as String?,
  readAtUtc: json['readAtUtc'] == null
      ? null
      : DateTime.parse(json['readAtUtc'] as String),
);

Map<String, dynamic> _$InboxNotificationResToJson(
  InboxNotificationRes instance,
) => <String, dynamic>{
  'id': instance.id,
  'kind': instance.kind,
  'title': instance.title,
  'body': instance.body,
  'actorUserId': instance.actorUserId,
  'data': instance.data,
  'createdAtUtc': instance.createdAtUtc.toIso8601String(),
  'readAtUtc': instance.readAtUtc?.toIso8601String(),
};
