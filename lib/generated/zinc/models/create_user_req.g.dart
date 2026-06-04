// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_user_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateUserReq _$CreateUserReqFromJson(Map<String, dynamic> json) =>
    CreateUserReq(
      idToken: json['idToken'] as String?,
      accessToken: json['accessToken'] as String?,
    );

Map<String, dynamic> _$CreateUserReqToJson(CreateUserReq instance) =>
    <String, dynamic>{
      'idToken': instance.idToken,
      'accessToken': instance.accessToken,
    };
