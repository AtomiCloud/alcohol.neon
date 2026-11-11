import '../../core/problem.dart';

/// zinc's tiers, cheapest first. zinc itself orders plans by price; this is the
/// app's copy for gating UI only — zinc still enforces every limit.
const _tierOrder = ['free', 'pro', 'ultimate'];

/// Whether [tier] is at least [minTier]. Unknown or missing values count as
/// allowed, so a new server-side tier never hides a feature; zinc answers
/// with a tier error if the user really can't use it.
bool tierMeets(String? tier, String? minTier) {
  if (minTier == null) return true;
  final have = _tierOrder.indexOf((tier ?? '').toLowerCase());
  final need = _tierOrder.indexOf(minTier.toLowerCase());
  if (have < 0 || need < 0) return true;
  return have >= need;
}

/// `pro` → `Pro`.
String tierLabel(String tier) =>
    tier.isEmpty ? tier : tier[0].toUpperCase() + tier.substring(1);

/// zinc's TierInsufficient problem (type ending in `tier_insufficient`).
bool isTierProblem(Problem p) {
  final t = p.type.toLowerCase();
  final ti = p.title.toLowerCase();
  return t.contains('tier_insufficient') ||
      (ti.contains('tier') && ti.contains('insufficient'));
}
