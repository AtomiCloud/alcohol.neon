// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'friend_request_res.dart';

part 'friend_requests_res.g.dart';

@JsonSerializable()
class FriendRequestsRes {
  const FriendRequestsRes({this.incoming, this.outgoing});

  factory FriendRequestsRes.fromJson(Map<String, Object?> json) =>
      _$FriendRequestsResFromJson(json);

  final List<FriendRequestRes>? incoming;
  final List<FriendRequestRes>? outgoing;

  Map<String, Object?> toJson() => _$FriendRequestsResToJson(this);
}
