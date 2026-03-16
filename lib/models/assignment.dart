class Assignment {
  final int id;
  final String title;
  final String bookTitle;
  final String chapter;
  final String dueDate;
  final int classroomId;

  Assignment({
    required this.id,
    required this.title,
    required this.bookTitle,
    required this.chapter,
    required this.dueDate,
    required this.classroomId,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) {
    return Assignment(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '') as String,
      bookTitle: (json['bookTitle'] ?? '') as String,
      chapter: (json['chapter'] ?? '') as String,
      dueDate: (json['dueDate'] ?? '') as String,
      classroomId: (json['classroomId'] as num?)?.toInt() ?? 0,
    );
  }
}