// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'friend_candidate_res.g.dart';

@JsonSerializable()
class FriendCandidateRes {
  const FriendCandidateRes({this.userId, this.username, this.relation});

  factory FriendCandidateRes.fromJson(Map<String, Object?> json) =>
      _$FriendCandidateResFromJson(json);

  final String? userId;
  final String? username;
  final String? relation;

  Map<String, Object?> toJson() => _$FriendCandidateResToJson(this);
}
