import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/problem.dart';

/// Minimal async HTTP client for the zinc REST API. Every call returns `Result<T>`
/// (no throwing across boundaries). Bearer tokens are supplied lazily via
/// [tokenProvider], which mints a Logto access token for the zinc resource on demand.
class ApiClient {
  final Uri baseUrl;
  final Future<String?> Function() tokenProvider;
  final http.Client _client;

  ApiClient({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<Result<T>> get<T>(
    String path,
    T Function(dynamic json) decode, {
    bool requiresAuth = true,
  }) async {
    final uri = baseUrl.resolve(path);
    final headers = <String, String>{'Accept': 'application/json'};

    if (requiresAuth) {
      final token = await tokenProvider();
      if (token == null) return const Err(Problem.unauthenticated);
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response res;
    try {
      res = await _client.get(uri, headers: headers);
    } catch (e) {
      return Err(Problem.network(e));
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      // Prefer the server's RFC 7807 body; fall back to a synthetic Problem.
      try {
        return Err(Problem.fromJson(jsonDecode(res.body) as Map<String, dynamic>));
      } catch (_) {
        return Err(Problem.local('Request failed',
            status: res.statusCode, detail: res.body.isEmpty ? null : res.body));
      }
    }

    try {
      final json = res.body.isEmpty ? null : jsonDecode(res.body);
      return Ok(decode(json));
    } catch (e) {
      return Err(Problem.decoding(e));
    }
  }
}
