// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_invite_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendInviteRes _$FriendInviteResFromJson(Map<String, dynamic> json) =>
    FriendInviteRes(
      expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String),
      code: json['code'] as String?,
    );

Map<String, dynamic> _$FriendInviteResToJson(FriendInviteRes instance) =>
    <String, dynamic>{
      'code': instance.code,
      'expiresAtUtc': instance.expiresAtUtc.toIso8601String(),
    };
