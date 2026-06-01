// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_user_req.g.dart';

@JsonSerializable()
class UpdateUserReq {
  const UpdateUserReq({
    this.idToken,
    this.accessToken,
  });
  
  factory UpdateUserReq.fromJson(Map<String, Object?> json) => _$UpdateUserReqFromJson(json);
  
  final String? idToken;
  final String? accessToken;

  Map<String, Object?> toJson() => _$UpdateUserReqToJson(this);
}
