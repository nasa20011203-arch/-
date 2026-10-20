String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

List<DateTime> monthCells(DateTime month) {
  final first = DateTime(month.year, month.month);
  final offset = first.weekday % 7;
  final days = DateTime(month.year, month.month + 1, 0).day;
  final count = ((offset + days + 6) ~/ 7) * 7;
  // Construct civil dates rather than adding 24h across a DST boundary.
  return List.generate(
    count,
    (index) => DateTime(month.year, month.month, 1 - offset + index),
  );
}

void requireDateKey(String date) {
  final parsed = DateTime.tryParse(date);
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
      parsed == null ||
      dateKey(parsed) != date) {
    throw FormatException('Invalid calendar date', date);
  }
}
