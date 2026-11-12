import 'dart:convert';

/// The proof plugin key zinc uses for Strava.
const stravaPluginKey = 'strava';

/// Strava sport types most people bind, shown first in the picker.
const _popular = [
  'Run',
  'TrailRun',
  'Walk',
  'Hike',
  'Ride',
  'Swim',
  'WeightTraining',
  'Workout',
  'Yoga',
];

/// The sport types the Strava manifest's settingsSchema allows
/// (`properties.sportTypes.items.enum`), popular ones first. Empty when the
/// schema can't be read.
List<String> sportTypesFromSchema(String? schemaJson) {
  if (schemaJson == null || schemaJson.isEmpty) return const [];
  try {
    final schema = jsonDecode(schemaJson);
    final values =
        schema['properties']['sportTypes']['items']['enum'] as List<dynamic>;
    final all = values.whereType<String>().toList();
    return [
      for (final p in _popular)
        if (all.contains(p)) p,
      for (final t in all)
        if (!_popular.contains(t)) t,
    ];
  } catch (_) {
    return const [];
  }
}

/// A binding's settings JSON → its sport types (empty when unreadable).
List<String> sportTypesFromSettings(String? settingsJson) {
  if (settingsJson == null || settingsJson.isEmpty) return const [];
  try {
    final raw = jsonDecode(settingsJson)['sportTypes'] as List<dynamic>;
    return raw.whereType<String>().toList();
  } catch (_) {
    return const [];
  }
}

/// The settings JSON string zinc expects, e.g. `{"sportTypes":["Run"]}`.
String encodeStravaSettings(Iterable<String> sportTypes) =>
    jsonEncode({'sportTypes': sportTypes.toList()});

/// `TrailRun` → `Trail run`, `EBikeRide` → `E bike ride`.
String sportTypeLabel(String sportType) {
  final words = sportType
      .replaceAllMapped(
        RegExp(r'(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])'),
        (_) => ' ',
      )
      .split(' ');
  return [
    words.first,
    for (final w in words.skip(1)) w.length > 1 ? w.toLowerCase() : w,
  ].join(' ');
}
