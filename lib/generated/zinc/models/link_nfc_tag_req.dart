// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'link_nfc_tag_req.g.dart';

@JsonSerializable()
class LinkNfcTagReq {
  const LinkNfcTagReq({required this.habitId});

  factory LinkNfcTagReq.fromJson(Map<String, Object?> json) =>
      _$LinkNfcTagReqFromJson(json);

  final String habitId;

  Map<String, Object?> toJson() => _$LinkNfcTagReqToJson(this);
}
