// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_user_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateUserReq _$UpdateUserReqFromJson(Map<String, dynamic> json) =>
    UpdateUserReq(
      idToken: json['idToken'] as String?,
      accessToken: json['accessToken'] as String?,
    );

Map<String, dynamic> _$UpdateUserReqToJson(UpdateUserReq instance) =>
    <String, dynamic>{
      'idToken': instance.idToken,
      'accessToken': instance.accessToken,
    };
