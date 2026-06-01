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
    Map<String, dynamic>? query,
  }) async {
    var uri = baseUrl.resolve(path);
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {
        ...uri.queryParameters,
        for (final e in query.entries)
          if (e.value != null) e.key: '${e.value}',
      });
    }

    final headers = await _headers(requiresAuth: requiresAuth);
    if (headers == null) return const Err(Problem.unauthenticated);

    http.Response res;
    try {
      res = await _client.get(uri, headers: headers);
    } catch (e) {
      return Err(Problem.network(e));
    }
    return _handle(res, decode);
  }

  Future<Result<T>> post<T>(
    String path,
    Object? body,
    T Function(dynamic json) decode, {
    bool requiresAuth = true,
  }) async {
    final uri = baseUrl.resolve(path);
    final headers = await _headers(requiresAuth: requiresAuth);
    if (headers == null) return const Err(Problem.unauthenticated);
    if (body != null) headers['Content-Type'] = 'application/json';

    http.Response res;
    try {
      res = await _client.post(uri,
          headers: headers, body: body == null ? null : jsonEncode(body));
    } catch (e) {
      return Err(Problem.network(e));
    }
    return _handle(res, decode);
  }

  /// Builds request headers, injecting a Bearer token when [requiresAuth].
  /// Returns null if a token is required but unavailable (caller maps to a Problem).
  Future<Map<String, String>?> _headers({required bool requiresAuth}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (requiresAuth) {
      final token = await tokenProvider();
      if (token == null) return null;
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Maps an HTTP response into `Result<T>`: non-2xx → `Err(Problem)` (preferring
  /// the server's RFC 7807 body), 2xx → decode, decode failure → `Err`.
  Result<T> _handle<T>(http.Response res, T Function(dynamic json) decode) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
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
