// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'send_friend_request_req.g.dart';

@JsonSerializable()
class SendFriendRequestReq {
  const SendFriendRequestReq({this.toUserId});

  factory SendFriendRequestReq.fromJson(Map<String, Object?> json) =>
      _$SendFriendRequestReqFromJson(json);

  final String? toUserId;

  Map<String, Object?> toJson() => _$SendFriendRequestReqToJson(this);
}
