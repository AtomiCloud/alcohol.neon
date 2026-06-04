// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_vacation_req.g.dart';

@JsonSerializable()
class CreateVacationReq {
  const CreateVacationReq({
    this.startDate,
    this.endDate,
    this.timezone,
  });
  
  factory CreateVacationReq.fromJson(Map<String, Object?> json) => _$CreateVacationReqFromJson(json);
  
  final String? startDate;
  final String? endDate;
  final String? timezone;

  Map<String, Object?> toJson() => _$CreateVacationReqToJson(this);
}
