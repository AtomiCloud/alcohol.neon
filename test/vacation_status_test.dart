import 'package:alcohol_neon/features/vacation/vacation_controller.dart';
import 'package:alcohol_neon/generated/zinc/models/vacation_res.dart';
import 'package:flutter_test/flutter_test.dart';

/// Status computation from zinc dd-MM-yyyy dates, with an injected "now" so the
/// boundaries (start day inclusive, end day inclusive) are deterministic.
void main() {
  VacationRes v(String? start, String? end) =>
      VacationRes(id: 'v', startDate: start, endDate: end, timezone: 'UTC');

  final now = DateTime(2026, 6, 15);

  test('before start → upcoming', () {
    expect(
      vacationStatusFor(v('20-06-2026', '25-06-2026'), now: now),
      VacationStatus.upcoming,
    );
  });

  test('within window (inclusive of start and end) → active', () {
    expect(
      vacationStatusFor(v('15-06-2026', '20-06-2026'), now: now),
      VacationStatus.active,
    );
    expect(
      vacationStatusFor(v('10-06-2026', '15-06-2026'), now: now),
      VacationStatus.active,
    );
    expect(
      vacationStatusFor(v('10-06-2026', '20-06-2026'), now: now),
      VacationStatus.active,
    );
  });

  test('after end → ended', () {
    expect(
      vacationStatusFor(v('01-06-2026', '10-06-2026'), now: now),
      VacationStatus.ended,
    );
  });

  test('missing/unparseable start → upcoming', () {
    expect(
      vacationStatusFor(v(null, '20-06-2026'), now: now),
      VacationStatus.upcoming,
    );
    expect(
      vacationStatusFor(v('not-a-date', '20-06-2026'), now: now),
      VacationStatus.upcoming,
    );
  });

  test('started, no end → active', () {
    expect(
      vacationStatusFor(v('10-06-2026', null), now: now),
      VacationStatus.active,
    );
  });
}
