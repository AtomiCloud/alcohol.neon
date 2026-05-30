/// RFC 7807 Problem Details — the single error currency across the app (mirrors
/// alcohol.argon's `Problem` and the shape zinc returns). House rule: never throw
/// across boundaries — convert to `Result<T>` and carry a `Problem` on failure.
class Problem implements Exception {
  final String type;
  final String title;
  final int status;
  final String? detail;
  final String? instance;

  const Problem({
    required this.type,
    required this.title,
    required this.status,
    this.detail,
    this.instance,
  });

  factory Problem.fromJson(Map<String, dynamic> json) => Problem(
        type: json['type'] as String? ?? 'about:blank',
        title: json['title'] as String? ?? 'Error',
        status: (json['status'] as num?)?.toInt() ?? 0,
        detail: json['detail'] as String?,
        instance: json['instance'] as String?,
      );

  /// Locally-generated problems for failures that never reach the server.
  factory Problem.local(String title,
          {int status = 0, String? detail, String type = 'about:blank'}) =>
      Problem(type: type, title: title, status: status, detail: detail);

  static Problem network(Object error) =>
      Problem.local('Network error', detail: error.toString(), type: 'neon:network');

  static Problem decoding(Object error) =>
      Problem.local('Unexpected response', detail: error.toString(), type: 'neon:decoding');

  static const unauthenticated =
      Problem(type: 'neon:unauthenticated', title: 'Not signed in', status: 401);

  @override
  String toString() => 'Problem($status $title${detail != null ? ': $detail' : ''})';
}

/// Minimal `Result` type — `Ok` on success, `Err` carrying a [Problem] on failure.
/// Use Dart pattern matching: `switch (result) { case Ok(:final value): … }`.
sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

class Err<T> extends Result<T> {
  final Problem problem;
  const Err(this.problem);
}
