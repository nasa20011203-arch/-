import 'package:flutter_test/flutter_test.dart';
import 'package:offline_calendar/core/calendar_date.dart';

void main() {
  test('Sunday-first calendars use 4, 5, or 6 complete weeks', () {
    expect(monthCells(DateTime(2015, 2)).length, 28);
    expect(monthCells(DateTime(2026, 4)).length, 35);
    expect(monthCells(DateTime(2026, 8)).length, 42);
    for (var year = 2000; year < 2040; year++) {
      for (var month = 1; month <= 12; month++) {
        final cells = monthCells(DateTime(year, month));
        expect(cells.first.weekday, DateTime.sunday);
        expect(cells.last.weekday, DateTime.saturday);
        expect(
          cells.where((d) => d.month == month).length,
          DateTime(year, month + 1, 0).day,
        );
      }
    }
  });
  test('date keys include leap days and year boundary', () {
    expect(dateKey(DateTime(2024, 2, 29)), '2024-02-29');
    expect(dateKey(DateTime(2026, 13)), '2027-01-01');
  });
}
