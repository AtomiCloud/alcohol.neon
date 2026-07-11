/// Pure schedule check for tap-to-complete, extracted for unit tests.
library;

/// Whether the habit runs on [isoDate] (`yyyy-MM-dd`, the server-resolved
/// "today" **in the habit's timezone** — never the device clock, which can sit
/// on a different calendar day around midnight or while travelling).
/// [daysOfWeek] uses zinc's PascalCase day names (e.g. "Monday").
bool scheduledOnDate(List<String> daysOfWeek, String isoDate) {
  final date = DateTime.tryParse(isoDate);
  if (date == null) return false;
  const names = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];
  final weekday = names[date.weekday - 1];
  return daysOfWeek.any((d) => d.toLowerCase() == weekday);
}
