import '../core/problem.dart';
import '../generated/zinc/models/habit_execution_res.dart';
import '../generated/zinc/models/habit_version_res.dart';
import '../networking/api_client.dart';

/// zinc `NfcTag` mapping (`/api/v1.0/NfcTag/{userId}/{tagId}`): a physical
/// tag's permanent random id → one of the user's habits.
///
/// Hand-rolled models (not `generated/zinc`) because the NfcTag endpoints are
/// newer than the checked-in OpenAPI spec; the nested habit shapes reuse the
/// generated models so this stays contract-compatible. Fold into the generated
/// client on the next `swagger_parser` regeneration.
class NfcTagRes {
  final String id;
  final String userId;
  final String habitId;
  final String? claimedAt;

  const NfcTagRes({
    required this.id,
    required this.userId,
    required this.habitId,
    this.claimedAt,
  });

  factory NfcTagRes.fromJson(Map<String, Object?> json) => NfcTagRes(
    id: json['id'] as String,
    userId: json['userId'] as String,
    habitId: json['habitId'] as String,
    claimedAt: json['claimedAt'] as String?,
  );
}

/// `GET` resolve payload: the mapping + the habit's *current* version (always
/// complete against this — never a version stored on the tag) + today's
/// execution, if any, computed in the habit's timezone.
class NfcTagResolutionRes {
  final NfcTagRes tag;
  final HabitVersionRes habitVersion;
  final String today;
  final HabitExecutionRes? todayExecution;

  const NfcTagResolutionRes({
    required this.tag,
    required this.habitVersion,
    required this.today,
    this.todayExecution,
  });

  factory NfcTagResolutionRes.fromJson(Map<String, Object?> json) =>
      NfcTagResolutionRes(
        tag: NfcTagRes.fromJson(json['tag'] as Map<String, Object?>),
        habitVersion: HabitVersionRes.fromJson(
          json['habitVersion'] as Map<String, Object?>,
        ),
        today: json['today'] as String,
        todayExecution: json['todayExecution'] == null
            ? null
            : HabitExecutionRes.fromJson(
                json['todayExecution'] as Map<String, Object?>,
              ),
      );
}

class NfcTagRepository {
  final ApiClient _api;
  NfcTagRepository(this._api);

  static const _base = '/api/v1.0/NfcTag';

  /// Points the tag at a habit (`PUT`, create-or-replace). 409 when the tag is
  /// owned by another user (first-come-first-served).
  Future<Result<NfcTagRes>> link(String userId, String tagId, String habitId) {
    return _api.put('$_base/$userId/$tagId', {
      'habitId': habitId,
    }, (j) => NfcTagRes.fromJson(j as Map<String, Object?>));
  }

  /// Resolves a tag (`GET`). 404 when unclaimed, owned by another user, or the
  /// linked habit no longer exists — the server never leaks ownership.
  Future<Result<NfcTagResolutionRes>> resolve(String userId, String tagId) {
    return _api.get(
      '$_base/$userId/$tagId',
      (j) => NfcTagResolutionRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Unlinks the tag (`DELETE`, owner only) — releases it back to unclaimed.
  Future<Result<void>> unlink(String userId, String tagId) {
    return _api.delete('$_base/$userId/$tagId');
  }
}
