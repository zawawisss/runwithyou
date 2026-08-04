import 'package:health/health.dart';
import '../models/daily_metrics.dart';
import 'hive_service.dart';

class HealthService {
  static final Health _health = Health();

  static bool _isInitialized = false;

  static bool get isAvailable => _isInitialized;

  static Future<void> init() async {
    try {
      await _health.configure();
      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
  }

  static List<HealthDataType> get _allTypes => [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
      ];

  // NOTE: hasPermissions is known to be unreliable on Health Connect (may return
  // false even after permissions are granted). We skip it and let the native
  // API handle access control instead. Only used for requestAuthorization flow.
  static Future<bool> requestPermissions() async {
    try {
      final permissions = List.filled(_allTypes.length, HealthDataAccess.READ);
      final granted = await _health.requestAuthorization(_allTypes, permissions: permissions);
      return granted;
    } catch (_) {
      return false;
    }
  }

  // Keep a lightweight permission check only for the UI sync badge.
  static Future<bool> checkPermissions([List<HealthDataType>? types]) async {
    try {
      final checkTypes = types ?? _allTypes;
      final permissions = List.filled(checkTypes.length, HealthDataAccess.READ);
      return (await _health.hasPermissions(checkTypes, permissions: permissions)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<int?> fetchLatestHeartRate() async {
    // No permission gate — let Health Connect native API handle access.
    try {
      final now = DateTime.now();
      final tenMinutesAgo = now.subtract(const Duration(minutes: 10));

      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: tenMinutesAgo,
        endTime: now,
      );

      if (data.isNotEmpty) {
        data.sort((a, b) => b.dateTo.compareTo(a.dateTo));
        final val = data.first.value;
        if (val is NumericHealthValue) return val.numericValue.toInt();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<int?> fetchStepsInInterval(DateTime start, DateTime end) async {
    // No permission gate — let Health Connect native API handle access.
    try {
      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps;
    } catch (_) {
      return null;
    }
  }

  static Future<int?> fetchCaloriesInInterval(DateTime start, DateTime end) async {
    // No permission gate — let Health Connect native API handle access.
    try {
      final data = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: start,
        endTime: end,
      );
      int calories = 0;
      bool hasData = false;
      for (final point in data) {
        final val = point.value;
        if (val is NumericHealthValue) {
          calories += val.numericValue.toInt();
          hasData = true;
        }
      }
      return hasData ? calories : null;
    } catch (_) {
      return null;
    }
  }

  static Future<DailyMetricsModel?> fetchTodayMetrics() async {
    return fetchMetricsForDate(DateTime.now());
  }

  static Future<DailyMetricsModel?> fetchMetricsForDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      await HiveService.saveDiagnosticsLog('Starting sync for ${startOfDay.toIso8601String().substring(0, 10)}');

      // Sleep window: 20:00 yesterday → 12:00 today
      // Covers night sleep that starts before midnight and ends in the morning.
      final sleepWindowStart = startOfDay.subtract(const Duration(hours: 4));
      final sleepWindowEnd = startOfDay.add(const Duration(hours: 12));

      int? steps;
      int? calories;
      double? sleepHours;
      int? avgHeartRate;

      // 1. Fetch steps — no permission gate, let native handle it
      try {
        steps = await _health.getTotalStepsInInterval(startOfDay, endOfDay);
        await HiveService.saveDiagnosticsLog('Steps success: $steps');
      } catch (e) {
        await HiveService.saveDiagnosticsLog('Steps failed: $e');
      }

      // 2. Fetch active calories (ACTIVE_ENERGY_BURNED), fallback to total calories (TOTAL_CALORIES_BURNED), then basal (BASAL_ENERGY_BURNED)
      final calorieTypes = [
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
      ];
      for (final calType in calorieTypes) {
        if (calories != null) break;
        try {
          final calorieData = await _health.getHealthDataFromTypes(
            types: [calType],
            startTime: startOfDay,
            endTime: endOfDay,
          );
          await HiveService.saveDiagnosticsLog('Calorie points count ($calType): ${calorieData.length}');
          if (calorieData.isNotEmpty) {
            int tempCalories = 0;
            bool valid = false;
            for (final point in calorieData) {
              final val = point.value;
              if (val is NumericHealthValue) {
                tempCalories += val.numericValue.toInt();
                valid = true;
              }
            }
            if (valid && tempCalories > 0) {
              calories = tempCalories;
              await HiveService.saveDiagnosticsLog('Calorie success ($calType): $calories kcal');
            }
          }
        } catch (e) {
          await HiveService.saveDiagnosticsLog('Calorie failed ($calType): $e');
        }
      }

      // 3. Fetch sleep using extended window (previous evening → midday today)
      // SLEEP_IN_BED is Apple-only; on Health Connect use SLEEP_SESSION / SLEEP_ASLEEP
      // Also try subtypes (SLEEP_DEEP, SLEEP_LIGHT, SLEEP_REM) — some watches
      // like Haylou write individual stages instead of sessions.
      final sleepTypes = [
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
      ];
      for (final sleepType in sleepTypes) {
        if (sleepHours != null) break;
        try {
          final sleepData = await _health.getHealthDataFromTypes(
            types: [sleepType],
            startTime: sleepWindowStart,
            endTime: sleepWindowEnd,
          );
          await HiveService.saveDiagnosticsLog('Sleep points count ($sleepType): ${sleepData.length}');
          if (sleepData.isNotEmpty) {
            double tempSleep = 0;
            for (final point in sleepData) {
              final val = point.value;
              if (val is NumericHealthValue) {
                // v13+: value is already in minutes
                tempSleep += val.numericValue / 60.0;
              } else {
                // Fallback: compute from dateFrom/dateTo
                final dur = point.dateTo.difference(point.dateFrom).inMinutes;
                if (dur > 0) tempSleep += dur / 60.0;
              }
            }
            if (tempSleep > 0) {
              sleepHours = tempSleep;
              await HiveService.saveDiagnosticsLog('Sleep success ($sleepType): $sleepHours hours');
            }
          }
        } catch (e) {
          await HiveService.saveDiagnosticsLog('Sleep failed ($sleepType): $e');
        }
      }

      // 4. Fetch heart rate — no permission gate
      try {
        final hrData = await _health.getHealthDataFromTypes(
          types: [HealthDataType.HEART_RATE],
          startTime: startOfDay,
          endTime: endOfDay,
        );
        await HiveService.saveDiagnosticsLog('HR points count: ${hrData.length}');
        if (hrData.isNotEmpty) {
          final rates = hrData
              .map((p) => p.value)
              .whereType<NumericHealthValue>()
              .map((v) => v.numericValue.toInt())
              .toList();
          if (rates.isNotEmpty) {
            avgHeartRate = rates.reduce((a, b) => a + b) ~/ rates.length;
            await HiveService.saveDiagnosticsLog('HR success: $avgHeartRate bpm');
          }
        }
      } catch (e) {
        await HiveService.saveDiagnosticsLog('HR failed: $e');
      }

      await HiveService.saveDiagnosticsLog('Finished sync. Steps: $steps, Calories: $calories, Sleep: $sleepHours, HR: $avgHeartRate');

      return DailyMetricsModel(
        sleepHours: sleepHours,
        steps: steps,
        calories: calories,
        averageHeartRate: avgHeartRate,
        date: date,
      );
    } catch (e) {
      await HiveService.saveDiagnosticsLog('Sync main loop error: $e');
      return null;
    }
  }

  /// Fetch 7-day history for a specific metric type.
  /// Returns a list of (date, value) pairs for each day.
  static Future<List<MapEntry<DateTime, double>>> fetch7DayHistory(String metricType) async {
    try {
      final now = DateTime.now();
      final results = <MapEntry<DateTime, double>>[];

      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        double? value;

        switch (metricType) {
          case 'steps':
            try {
              final steps = await _health.getTotalStepsInInterval(startOfDay, endOfDay);
              if (steps != null && steps > 0) value = steps.toDouble();
            } catch (_) {}
            break;

          case 'calories':
            final calTypes = [
              HealthDataType.ACTIVE_ENERGY_BURNED,
              HealthDataType.TOTAL_CALORIES_BURNED,
              HealthDataType.BASAL_ENERGY_BURNED,
            ];
            for (final calType in calTypes) {
              if (value != null) break;
              try {
                final data = await _health.getHealthDataFromTypes(
                  types: [calType],
                  startTime: startOfDay,
                  endTime: endOfDay,
                );
                if (data.isNotEmpty) {
                  double total = 0;
                  bool valid = false;
                  for (final point in data) {
                    final val = point.value;
                    if (val is NumericHealthValue) {
                      total += val.numericValue;
                      valid = true;
                    }
                  }
                  if (valid && total > 0) value = total;
                }
              } catch (_) {}
            }
            break;

          case 'sleep':
            final sleepWindowStart = startOfDay.subtract(const Duration(hours: 4));
            final sleepWindowEnd = startOfDay.add(const Duration(hours: 12));
            final sleepTypes = [
              HealthDataType.SLEEP_SESSION,
              HealthDataType.SLEEP_ASLEEP,
              HealthDataType.SLEEP_DEEP,
              HealthDataType.SLEEP_LIGHT,
              HealthDataType.SLEEP_REM,
            ];
            for (final sleepType in sleepTypes) {
              if (value != null) break;
              try {
                final data = await _health.getHealthDataFromTypes(
                  types: [sleepType],
                  startTime: sleepWindowStart,
                  endTime: sleepWindowEnd,
                );
                if (data.isNotEmpty) {
                  double totalMinutes = 0;
                  for (final point in data) {
                    final val = point.value;
                    if (val is NumericHealthValue) {
                      totalMinutes += val.numericValue;
                    } else {
                      totalMinutes += point.dateTo.difference(point.dateFrom).inMinutes;
                    }
                  }
                  if (totalMinutes > 0) value = totalMinutes / 60.0;
                }
              } catch (_) {}
            }
            break;

          case 'heartRate':
            try {
              final data = await _health.getHealthDataFromTypes(
                types: [HealthDataType.HEART_RATE],
                startTime: startOfDay,
                endTime: endOfDay,
              );
              if (data.isNotEmpty) {
                final rates = data
                    .map((p) => p.value)
                    .whereType<NumericHealthValue>()
                    .map((v) => v.numericValue)
                    .toList();
                if (rates.isNotEmpty) {
                  value = rates.reduce((a, b) => a + b) / rates.length;
                }
              }
            } catch (_) {}
            break;
        }

        results.add(MapEntry(date, value ?? 0));
      }

      return results;
    } catch (_) {
      return List.generate(7, (i) => MapEntry(DateTime.now().subtract(Duration(days: 6 - i)), 0.0));
    }
  }

  /// Debug: log how many data points exist for every common Health Connect type
  /// in the last 7 days. Call from diagnostics screen to see what the watch
  /// actually writes to Health Connect.
  static Future<void> dumpAvailableData() async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));

      final allTypes = [
        HealthDataType.STEPS,
        HealthDataType.HEART_RATE,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_AWAKE_IN_BED,
        HealthDataType.SLEEP_OUT_OF_BED,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.TOTAL_CALORIES_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.BODY_TEMPERATURE,
        HealthDataType.BODY_FAT_PERCENTAGE,
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.BODY_MASS_INDEX,
      ];

      await HiveService.saveDiagnosticsLog('=== Health Connect Data Dump (last 7 days) ===');

      for (final type in allTypes) {
        try {
          final data = await _health.getHealthDataFromTypes(
            types: [type],
            startTime: sevenDaysAgo,
            endTime: now,
          );
          String detail = '${type.name}: ${data.length} points';
          // Log first data point details for sleep types to debug
          if (data.isNotEmpty && type.name.startsWith('SLEEP')) {
            final first = data.first;
            detail += ' | first: ${first.dateFrom} → ${first.dateTo} val=${first.value}';
          }
          await HiveService.saveDiagnosticsLog(detail);
        } catch (e) {
          await HiveService.saveDiagnosticsLog('${type.name}: ERROR $e');
        }
      }

      await HiveService.saveDiagnosticsLog('=== End Dump ===');
    } catch (_) {}
  }
}
