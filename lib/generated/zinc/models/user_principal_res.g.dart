// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_principal_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserPrincipalRes _$UserPrincipalResFromJson(Map<String, dynamic> json) =>
    UserPrincipalRes(
      emailVerified: json['emailVerified'] as bool,
      active: json['active'] as bool,
      id: json['id'] as String?,
      username: json['username'] as String?,
      email: json['email'] as String?,
    );

Map<String, dynamic> _$UserPrincipalResToJson(UserPrincipalRes instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'email': instance.email,
      'emailVerified': instance.emailVerified,
      'active': instance.active,
    };
