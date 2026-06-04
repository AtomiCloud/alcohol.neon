/// Date formatting that matches the zinc contract exactly. zinc's
/// `Utils.StandardDateFormat` is **dd-MM-yyyy** (NOT ISO yyyy-MM-dd): vacation
/// `startDate`/`endDate` are sent and received in this format. Keep all
/// DateTime ↔ string conversions for vacations going through here so the format
/// string is never scattered or accidentally swapped for ISO.
library;

/// Formats a [DateTime] (date part only) as zinc's `dd-MM-yyyy`.
String formatStandardDate(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString().padLeft(4, '0');
  return '$dd-$mm-$yyyy';
}

/// Parses a zinc `dd-MM-yyyy` string into a date-only [DateTime] (local, midnight).
/// Returns null when the input is null, malformed, or out of range — never throws,
/// so callers can branch on a missing/invalid date rather than catch.
DateTime? tryParseStandardDate(String? value) {
  if (value == null) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final dd = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);
  final yyyy = int.tryParse(parts[2]);
  if (dd == null || mm == null || yyyy == null) return null;
  if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
  final parsed = DateTime(yyyy, mm, dd);
  // Reject overflow (e.g. 31-02-2026 → 03-03-2026): round-trip must match.
  if (parsed.day != dd || parsed.month != mm || parsed.year != yyyy) return null;
  return parsed;
}
