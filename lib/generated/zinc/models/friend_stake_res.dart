// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'friend_watcher_res.dart';

part 'friend_stake_res.g.dart';

@JsonSerializable()
class FriendStakeRes {
  const FriendStakeRes({required this.habitId, this.friends});

  factory FriendStakeRes.fromJson(Map<String, Object?> json) =>
      _$FriendStakeResFromJson(json);

  final String habitId;
  final List<FriendWatcherRes>? friends;

  Map<String, Object?> toJson() => _$FriendStakeResToJson(this);
}
