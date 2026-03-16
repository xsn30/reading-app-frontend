class Question {
  final int id;
  final int assignmentId;
  final String type;
  final String text;
  final List<String> options;
  final int score;
  final String difficulty;
  final String correctAnswer;

  Question({
    required this.id,
    required this.assignmentId,
    required this.type,
    required this.text,
    required this.options,
    required this.score,
    required this.difficulty,
    required this.correctAnswer,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];

    final List<String> options = (rawOptions is List)
        ? rawOptions.map((e) => e.toString()).toList()
        : <String>[];

    return Question(
      id: (json['id'] as num).toInt(),
      assignmentId: (json['assignmentId'] as num).toInt(),
      type: (json['type'] ?? '') as String,
      text: (json['text'] ?? '') as String,
      options: options,
      score: (json['score'] is num) ? (json['score'] as num).toInt() : 1,
      difficulty: (json['difficulty'] ?? '') as String,
      correctAnswer: (json['correctAnswer'] ?? '') as String,
    );
  }
}