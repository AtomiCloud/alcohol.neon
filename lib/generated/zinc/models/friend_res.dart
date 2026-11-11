// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'friend_res.g.dart';

@JsonSerializable()
class FriendRes {
  const FriendRes({required this.sinceUtc, this.userId, this.username});

  factory FriendRes.fromJson(Map<String, Object?> json) =>
      _$FriendResFromJson(json);

  final String? userId;
  final String? username;
  final DateTime sinceUtc;

  Map<String, Object?> toJson() => _$FriendResToJson(this);
}
