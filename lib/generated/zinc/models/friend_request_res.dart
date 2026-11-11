// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'friend_request_res.g.dart';

@JsonSerializable()
class FriendRequestRes {
  const FriendRequestRes({
    required this.createdAtUtc,
    this.userId,
    this.username,
  });

  factory FriendRequestRes.fromJson(Map<String, Object?> json) =>
      _$FriendRequestResFromJson(json);

  final String? userId;
  final String? username;
  final DateTime createdAtUtc;

  Map<String, Object?> toJson() => _$FriendRequestResToJson(this);
}
