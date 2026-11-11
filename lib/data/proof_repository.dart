import '../core/problem.dart';
import '../generated/zinc/models/bind_proof_req.dart';
import '../generated/zinc/models/plugin_manifest_res.dart';
import '../generated/zinc/models/proof_binding_res.dart';
import '../networking/api_client.dart';

/// zinc `/Proof` endpoints: the proof plugins (Strava, …) and which one a habit
/// is bound to. A habit with no binding reads back as the `manual` plugin.
class ProofRepository {
  final ApiClient _api;
  ProofRepository(this._api);

  static const _base = '/api/v1.0/Proof';

  /// Every plugin's manifest (`GET /Proof/plugins`).
  Future<Result<List<PluginManifestRes>>> plugins() {
    return _api.get(
      '$_base/plugins',
      (j) => (j as List<dynamic>)
          .map((e) => PluginManifestRes.fromJson(e as Map<String, Object?>))
          .toList(),
    );
  }

  /// The habit's binding (`GET /Proof/{userId}/{habitId}`).
  Future<Result<ProofBindingRes>> binding(String userId, String habitId) {
    return _api.get(
      '$_base/$userId/$habitId',
      (j) => ProofBindingRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Binds the habit to [pluginKey], replacing any binding
  /// (`PUT /Proof/{userId}/{habitId}`). [settings] is a JSON string.
  Future<Result<ProofBindingRes>> bind(
    String userId,
    String habitId, {
    required String pluginKey,
    required String settings,
  }) {
    return _api.put(
      '$_base/$userId/$habitId',
      BindProofReq(pluginKey: pluginKey, settings: settings).toJson(),
      (j) => ProofBindingRes.fromJson(j as Map<String, Object?>),
    );
  }

  /// Puts the habit back on manual check-in (`DELETE /Proof/{userId}/{habitId}`).
  Future<Result<void>> unbind(String userId, String habitId) {
    return _api.delete('$_base/$userId/$habitId');
  }
}
