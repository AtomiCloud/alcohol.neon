import 'package:flutter/foundation.dart';

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
  factory Problem.local(
    String title, {
    int status = 0,
    String? detail,
    String type = 'about:blank',
  }) => Problem(type: type, title: title, status: status, detail: detail);

  /// The request never got an answer (offline, DNS, timeout). The detail is
  /// shown on screen, so it says what to do; the exception goes to the log.
  static Problem network(Object error) {
    debugPrint('Network error: $error');
    return Problem.local(
      'Network error',
      detail: 'Check your connection and try again.',
      type: 'neon:network',
    );
  }

  /// The server answered with something the app can't read.
  static Problem decoding(Object error) {
    debugPrint('Unexpected response: $error');
    return Problem.local(
      'Unexpected response',
      detail: 'Something went wrong on our side. Try again in a moment.',
      type: 'neon:decoding',
    );
  }

  static const unauthenticated = Problem(
    type: 'neon:unauthenticated',
    title: 'Not signed in',
    status: 401,
  );

  /// What to render to the user: the detail when it carries real text, else the
  /// title. zinc can emit problems whose `detail` is `""` (non-null!), so a bare
  /// `detail ?? title` renders an invisible empty Text — always use this instead.
  String get displayMessage {
    final d = detail?.trim();
    return (d == null || d.isEmpty) ? title : d;
  }

  @override
  String toString() =>
      'Problem($status $title${detail != null ? ': $detail' : ''})';
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
