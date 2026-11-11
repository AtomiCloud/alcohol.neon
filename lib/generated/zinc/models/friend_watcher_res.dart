// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'friend_watcher_res.g.dart';

@JsonSerializable()
class FriendWatcherRes {
  const FriendWatcherRes({this.userId, this.username});

  factory FriendWatcherRes.fromJson(Map<String, Object?> json) =>
      _$FriendWatcherResFromJson(json);

  final String? userId;
  final String? username;

  Map<String, Object?> toJson() => _$FriendWatcherResToJson(this);
}
