class TaskModel {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime date;
  final String category;
  final int energyRequired; // 1 to 5
  final String timeOfDay; // 'Pagi', 'Siang', 'Sore', 'Malam'
  final String? startTime; // format 'HH:mm', optional for schedule-like tasks
  final String? endTime; // format 'HH:mm', optional
  final bool isRecurring; // if true, shows every day

  TaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    required this.date,
    required this.category,
    required this.energyRequired,
    required this.timeOfDay,
    this.startTime,
    this.endTime,
    this.isRecurring = false,
  });

  bool get hasTime => startTime != null && endTime != null;

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? date,
    String? category,
    int? energyRequired,
    String? timeOfDay,
    String? startTime,
    String? endTime,
    bool? isRecurring,
    bool clearStartTime = false,
    bool clearEndTime = false,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      date: date ?? this.date,
      category: category ?? this.category,
      energyRequired: energyRequired ?? this.energyRequired,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      startTime: clearStartTime ? null : (startTime ?? this.startTime),
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted ? 1 : 0,
      'date': date.toIso8601String(),
      'category': category,
      'energyRequired': energyRequired,
      'timeOfDay': timeOfDay,
      'startTime': startTime,
      'endTime': endTime,
      'isRecurring': isRecurring ? 1 : 0,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      isCompleted: map['isCompleted'] == 1 || map['isCompleted'] == true,
      date: DateTime.parse(map['date'] as String),
      category: map['category'] as String,
      energyRequired: map['energyRequired'] as int,
      timeOfDay: map['timeOfDay'] as String,
      startTime: map['startTime'] as String?,
      endTime: map['endTime'] as String?,
      isRecurring: map['isRecurring'] == 1 || map['isRecurring'] == true,
    );
  }
}
