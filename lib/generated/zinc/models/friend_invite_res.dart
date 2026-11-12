// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'friend_invite_res.g.dart';

@JsonSerializable()
class FriendInviteRes {
  const FriendInviteRes({this.code});

  factory FriendInviteRes.fromJson(Map<String, Object?> json) =>
      _$FriendInviteResFromJson(json);

  final String? code;

  Map<String, Object?> toJson() => _$FriendInviteResToJson(this);
}
