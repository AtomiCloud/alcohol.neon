// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'friend_relation_res.g.dart';

@JsonSerializable()
class FriendRelationRes {
  const FriendRelationRes({this.relation});

  factory FriendRelationRes.fromJson(Map<String, Object?> json) =>
      _$FriendRelationResFromJson(json);

  final String? relation;

  Map<String, Object?> toJson() => _$FriendRelationResToJson(this);
}
