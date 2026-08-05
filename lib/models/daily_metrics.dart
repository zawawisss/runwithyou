class DailyMetricsModel {
  final double? sleepHours;
  final int? steps;
  final int? calories;
  final int? averageHeartRate;
  final DateTime date;

  DailyMetricsModel({
    this.sleepHours,
    this.steps,
    this.calories,
    this.averageHeartRate,
    required this.date,
  });

  /// true saat ada setidaknya satu data kesehatan nyata (bukan nol/null).
  /// Dipakai untuk menampilkan placeholder "Fitur Kesehatan — Segera Hadir"
  /// selama Health Connect belum terkirim data (via bridge Health Sync).
  bool get hasAnyHealthData =>
      steps != null ||
      calories != null ||
      averageHeartRate != null ||
      sleepHours != null;

  DailyMetricsModel copyWith({
    double? sleepHours,
    int? steps,
    int? calories,
    int? averageHeartRate,
    DateTime? date,
  }) {
    return DailyMetricsModel(
      sleepHours: sleepHours ?? this.sleepHours,
      steps: steps ?? this.steps,
      calories: calories ?? this.calories,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sleepHours': sleepHours,
      'steps': steps,
      'calories': calories,
      'averageHeartRate': averageHeartRate,
      'date': date.toIso8601String(),
    };
  }

  factory DailyMetricsModel.fromMap(Map<String, dynamic> map) {
    return DailyMetricsModel(
      sleepHours: map['sleepHours'] != null ? (map['sleepHours'] as num).toDouble() : null,
      steps: map['steps'] as int?,
      calories: map['calories'] as int?,
      averageHeartRate: map['averageHeartRate'] as int?,
      date: DateTime.parse(map['date'] as String),
    );
  }
}
