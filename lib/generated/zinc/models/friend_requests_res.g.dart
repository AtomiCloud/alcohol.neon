// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_requests_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendRequestsRes _$FriendRequestsResFromJson(Map<String, dynamic> json) =>
    FriendRequestsRes(
      incoming: (json['incoming'] as List<dynamic>?)
          ?.map((e) => FriendRequestRes.fromJson(e as Map<String, dynamic>))
          .toList(),
      outgoing: (json['outgoing'] as List<dynamic>?)
          ?.map((e) => FriendRequestRes.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$FriendRequestsResToJson(FriendRequestsRes instance) =>
    <String, dynamic>{
      'incoming': instance.incoming,
      'outgoing': instance.outgoing,
    };
