class NoteModel {
  final String id;
  final String content;
  final int colorIndex; // 0 to 4 untuk warna pastel
  final DateTime date;

  NoteModel({
    required this.id,
    required this.content,
    required this.colorIndex,
    required this.date,
  });

  NoteModel copyWith({
    String? id,
    String? content,
    int? colorIndex,
    DateTime? date,
  }) {
    return NoteModel(
      id: id ?? this.id,
      content: content ?? this.content,
      colorIndex: colorIndex ?? this.colorIndex,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'colorIndex': colorIndex,
      'date': date.toIso8601String(),
    };
  }

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      id: map['id'] as String,
      content: map['content'] as String,
      colorIndex: map['colorIndex'] as int,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
