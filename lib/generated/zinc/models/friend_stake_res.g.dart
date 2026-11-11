// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_stake_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FriendStakeRes _$FriendStakeResFromJson(Map<String, dynamic> json) =>
    FriendStakeRes(
      habitId: json['habitId'] as String,
      friends: (json['friends'] as List<dynamic>?)
          ?.map((e) => FriendWatcherRes.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$FriendStakeResToJson(FriendStakeRes instance) =>
    <String, dynamic>{'habitId': instance.habitId, 'friends': instance.friends};
