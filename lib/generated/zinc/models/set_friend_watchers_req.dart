// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'set_friend_watchers_req.g.dart';

@JsonSerializable()
class SetFriendWatchersReq {
  const SetFriendWatchersReq({this.friendUserIds});

  factory SetFriendWatchersReq.fromJson(Map<String, Object?> json) =>
      _$SetFriendWatchersReqFromJson(json);

  final List<String>? friendUserIds;

  Map<String, Object?> toJson() => _$SetFriendWatchersReqToJson(this);
}
