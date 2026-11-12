import '../core/problem.dart';
import '../networking/api_client.dart';

class FriendWatcherRes {
  final String userId;
  final String username;

  const FriendWatcherRes({required this.userId, required this.username});

  factory FriendWatcherRes.fromJson(Map<String, Object?> json) =>
      FriendWatcherRes(
        userId: json['userId'] as String,
        username: json['username'] as String? ?? '',
      );
}

/// The friends told when the habit's day ends Missed.
///
/// Hand-rolled (not `generated/zinc`): pichu's checked-in OpenAPI spec predates
/// the FriendStake endpoints (zinc ≥ 1.39). Fold into the generated models on
/// the next `swagger_parser` regeneration.
class FriendStakeRes {
  final String habitId;
  final List<FriendWatcherRes> friends;

  const FriendStakeRes({required this.habitId, required this.friends});

  factory FriendStakeRes.fromJson(Map<String, Object?> json) => FriendStakeRes(
    habitId: json['habitId'] as String? ?? '',
    friends: [
      for (final e in (json['friends'] as List<dynamic>? ?? const []))
        FriendWatcherRes.fromJson(e as Map<String, Object?>),
    ],
  );
}

/// zinc `/FriendStake` endpoints ("Tell my friends if I miss").
class FriendStakeRepository {
  final ApiClient _api;
  FriendStakeRepository(this._api);

  static const _base = '/api/v1.0/FriendStake';

  /// Most friends one habit can tell (zinc's FriendStakeService.MaxWatchers).
  static const maxWatchers = 20;

  Future<Result<FriendStakeRes>> get(String userId, String habitId) {
    return _api.get(
      '$_base/$userId/$habitId',
      (j) => FriendStakeRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Replaces the habit's watchers; an empty list turns it off.
  Future<Result<FriendStakeRes>> set(
    String userId,
    String habitId,
    List<String> friendUserIds,
  ) {
    return _api.put('$_base/$userId/$habitId', {
      'friendUserIds': friendUserIds,
    }, (j) => FriendStakeRes.fromJson(j as Map<String, Object?>));
  }
}
