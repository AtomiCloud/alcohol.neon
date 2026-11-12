import '../core/problem.dart';
import '../networking/api_client.dart';

// Hand-rolled models (not `generated/zinc`): pichu's checked-in OpenAPI spec
// predates the Friend endpoints (zinc ≥ 1.39). Fold into the generated models
// on the next `swagger_parser` regeneration.

/// A search hit. [relation] is `none` | `friend` | `outgoing` (you asked them)
/// | `incoming` (they asked you).
class FriendCandidateRes {
  final String userId;
  final String username;
  final String relation;

  const FriendCandidateRes({
    required this.userId,
    required this.username,
    required this.relation,
  });

  factory FriendCandidateRes.fromJson(Map<String, Object?> json) =>
      FriendCandidateRes(
        userId: json['userId'] as String,
        username: json['username'] as String? ?? '',
        relation: json['relation'] as String? ?? 'none',
      );
}

class FriendRes {
  final String userId;
  final String username;
  final DateTime? sinceUtc;

  const FriendRes({
    required this.userId,
    required this.username,
    this.sinceUtc,
  });

  factory FriendRes.fromJson(Map<String, Object?> json) => FriendRes(
    userId: json['userId'] as String,
    username: json['username'] as String? ?? '',
    sinceUtc: DateTime.tryParse(json['sinceUtc'] as String? ?? ''),
  );
}

/// The other person on a request: the sender for incoming, the recipient for
/// outgoing.
class FriendRequestRes {
  final String userId;
  final String username;
  final DateTime? createdAtUtc;

  const FriendRequestRes({
    required this.userId,
    required this.username,
    this.createdAtUtc,
  });

  factory FriendRequestRes.fromJson(Map<String, Object?> json) =>
      FriendRequestRes(
        userId: json['userId'] as String,
        username: json['username'] as String? ?? '',
        createdAtUtc: DateTime.tryParse(json['createdAtUtc'] as String? ?? ''),
      );
}

class FriendRequestsRes {
  final List<FriendRequestRes> incoming;
  final List<FriendRequestRes> outgoing;

  const FriendRequestsRes({required this.incoming, required this.outgoing});

  static List<FriendRequestRes> _list(Object? raw) => [
    for (final e in (raw as List<dynamic>? ?? const []))
      FriendRequestRes.fromJson(e as Map<String, Object?>),
  ];

  factory FriendRequestsRes.fromJson(Map<String, Object?> json) =>
      FriendRequestsRes(
        incoming: _list(json['incoming']),
        outgoing: _list(json['outgoing']),
      );
}

/// A 7-day invite. The app builds the link: `https://t.lazytax.club/f/{code}`.
class FriendInviteRes {
  final String code;
  final DateTime? expiresAtUtc;

  const FriendInviteRes({required this.code, this.expiresAtUtc});

  factory FriendInviteRes.fromJson(Map<String, Object?> json) =>
      FriendInviteRes(
        code: json['code'] as String,
        expiresAtUtc: DateTime.tryParse(json['expiresAtUtc'] as String? ?? ''),
      );
}

/// zinc `/Friend` endpoints, all scoped to the signed-in user.
class FriendRepository {
  final ApiClient _api;
  FriendRepository(this._api);

  static const _base = '/api/v1.0/Friend';

  /// Usernames starting with [q] (2+ characters, case-insensitive).
  Future<Result<List<FriendCandidateRes>>> search(
    String userId,
    String q, {
    int limit = 20,
  }) {
    return _api.get(
      '$_base/$userId/search',
      (j) => (j as List<dynamic>)
          .map((e) => FriendCandidateRes.fromJson(e as Map<String, Object?>))
          .toList(),
      query: {'q': q, 'limit': limit},
    );
  }

  Future<Result<List<FriendRes>>> friends(String userId) {
    return _api.get(
      '$_base/$userId',
      (j) => (j as List<dynamic>)
          .map((e) => FriendRes.fromJson(e as Map<String, Object?>))
          .toList(),
    );
  }

  Future<Result<void>> remove(String userId, String friendUserId) {
    return _api.delete('$_base/$userId/$friendUserId');
  }

  Future<Result<FriendRequestsRes>> requests(String userId) {
    return _api.get(
      '$_base/$userId/requests',
      (j) => FriendRequestsRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Sends a request; returns the new relation (`friend` when they had
  /// already asked you, which accepts theirs).
  Future<Result<String>> sendRequest(String userId, String toUserId) {
    return _api.post('$_base/$userId/requests', {
      'toUserId': toUserId,
    }, (j) => (j as Map<String, Object?>)['relation'] as String? ?? 'outgoing');
  }

  Future<Result<FriendRes>> accept(String userId, String fromUserId) {
    return _api.post(
      '$_base/$userId/requests/$fromUserId/accept',
      null,
      (j) => FriendRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Declines an incoming request or cancels an outgoing one.
  Future<Result<void>> deleteRequest(String userId, String otherUserId) {
    return _api.delete('$_base/$userId/requests/$otherUserId');
  }

  Future<Result<FriendInviteRes>> createInvite(String userId) {
    return _api.post(
      '$_base/$userId/invites',
      null,
      (j) => FriendInviteRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// 404 for an unknown or expired code, 400 for your own.
  Future<Result<FriendRes>> acceptInvite(String userId, String code) {
    return _api.post(
      '$_base/$userId/invites/${Uri.encodeComponent(code)}/accept',
      null,
      (j) => FriendRes.fromJson(j as Map<String, Object?>),
    );
  }
}
