// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_friend_watchers_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SetFriendWatchersReq _$SetFriendWatchersReqFromJson(
  Map<String, dynamic> json,
) => SetFriendWatchersReq(
  friendUserIds: (json['friendUserIds'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$SetFriendWatchersReqToJson(
  SetFriendWatchersReq instance,
) => <String, dynamic>{'friendUserIds': instance.friendUserIds};
