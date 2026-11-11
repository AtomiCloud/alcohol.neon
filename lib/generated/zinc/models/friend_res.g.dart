// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendRes _$FriendResFromJson(Map<String, dynamic> json) => FriendRes(
  sinceUtc: DateTime.parse(json['sinceUtc'] as String),
  userId: json['userId'] as String?,
  username: json['username'] as String?,
);

Map<String, dynamic> _$FriendResToJson(FriendRes instance) => <String, dynamic>{
  'userId': instance.userId,
  'username': instance.username,
  'sinceUtc': instance.sinceUtc.toIso8601String(),
};
