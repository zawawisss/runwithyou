class WorkoutModel {
  final String id;
  final double distance; // in km
  final int duration; // in seconds
  final int calories;
  final String averagePace; // format 'MM:SS' / 'km/h'
  final int averageHeartRate; // in bpm
  final DateTime date;

  WorkoutModel({
    required this.id,
    required this.distance,
    required this.duration,
    required this.calories,
    required this.averagePace,
    required this.averageHeartRate,
    required this.date,
  });

  WorkoutModel copyWith({
    String? id,
    double? distance,
    int? duration,
    int? calories,
    String? averagePace,
    int? averageHeartRate,
    DateTime? date,
  }) {
    return WorkoutModel(
      id: id ?? this.id,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      calories: calories ?? this.calories,
      averagePace: averagePace ?? this.averagePace,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'distance': distance,
      'duration': duration,
      'calories': calories,
      'averagePace': averagePace,
      'averageHeartRate': averageHeartRate,
      'date': date.toIso8601String(),
    };
  }

  factory WorkoutModel.fromMap(Map<String, dynamic> map) {
    return WorkoutModel(
      id: map['id'] as String,
      distance: (map['distance'] as num).toDouble(),
      duration: map['duration'] as int,
      calories: map['calories'] as int,
      averagePace: map['averagePace'] as String,
      averageHeartRate: map['averageHeartRate'] as int,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
