// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'nfc_tag_res.g.dart';

@JsonSerializable()
class NfcTagRes {
  const NfcTagRes({
    required this.habitId,
    this.id,
    this.userId,
    this.claimedAt,
  });

  factory NfcTagRes.fromJson(Map<String, Object?> json) =>
      _$NfcTagResFromJson(json);

  final String? id;
  final String? userId;
  final String habitId;
  final String? claimedAt;

  Map<String, Object?> toJson() => _$NfcTagResToJson(this);
}
