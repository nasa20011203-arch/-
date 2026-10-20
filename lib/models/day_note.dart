class DayNote {
  const DayNote({
    required this.id,
    required this.date,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.isDeleted,
  });
  final String id;
  final String date;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final bool isDeleted;
}
