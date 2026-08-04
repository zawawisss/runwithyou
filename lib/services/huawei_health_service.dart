import 'package:flutter/foundation.dart';
import 'package:huawei_health/huawei_health.dart';
import '../models/daily_metrics.dart';
import 'hive_service.dart';

/// Service untuk baca data kesehatan langsung dari Huawei Band
/// via Huawei Health Kit (HMS Core).
///
/// Berbeda dengan HealthService yang baca dari Health Connect (Google),
/// service ini baca langsung dari Huawei Health Kit tanpa perantara.
class HuaweiHealthService {
  static DataController? _dataController;
  static bool _isInitialized = false;
  static bool _isSignedIn = false;

  /// Nama paket aplikasi — harus sama dengan `applicationId` di build.gradle.kts
  /// dan nama paket yang didaftarkan di AppGallery Connect (agconnect-services.json).
  static const String packageName = 'com.example.runwithyou';

  static bool get isInitialized => _isInitialized;
  static bool get isSignedIn => _isSignedIn;

  /// Inisialisasi DataController. Panggil di main() sebelum runApp.
  static Future<void> init() async {
    try {
      _dataController = await DataController.init();
      _isInitialized = true;
    } catch (e) {
      debugPrint('HuaweiHealthService init error: $e');
      _isInitialized = false;
    }
  }

  /// Sign in dengan Huawei ID dan minta izin akses data kesehatan.
  static Future<bool> signIn() async {
    if (!_isInitialized || _dataController == null) return false;

    try {
      final List<Scope> scopes = [
        // App hanya baca — cukup scope READ. Scope WRITE tak dipakai (tidak ada
        // insert/update di service ini) dan menambah consent prompt + berisiko
        // gagal bila scope belum disetujui di konsol AGC.
        Scope.HEALTHKIT_STEP_READ,
        Scope.HEALTHKIT_HEARTRATE_READ,
        Scope.HEALTHKIT_SLEEP_READ,
        Scope.HEALTHKIT_CALORIES_READ,
        Scope.HEALTHKIT_DISTANCE_READ,
        Scope.HEALTHKIT_ACTIVITY_READ,
        Scope.HEALTHKIT_HEARTHEALTH_READ,
      ];

      final AuthHuaweiId? result = await HealthAuth.signIn(scopes);
      _isSignedIn = result != null;
      if (_isSignedIn) {
        // Connect ulang secara eksplisit — batalkan opt-out sebelumnya.
        await HiveService.setHuaweiOptOut(false);
      }
      return _isSignedIn;
    } catch (e) {
      debugPrint('HuaweiHealthService signIn error: $e');
      _isSignedIn = false;
      return false;
    }
  }

  /// Deteksi ulang status sign-in tanpa menampilkan layar login.
  ///
  /// Sesi HMS Core ter-restore otomatis setelah user pernah mengotorisasi sekali,
  /// jadi probe ringan (baca langkah hari ini) cukup untuk tahu apakah masih
  /// punya akses — sukses berarti tetap "terhubung" setelah restart app.
  static Future<bool> refreshSignInState() async {
    if (!_isInitialized || _dataController == null) {
      _isSignedIn = false;
      return false;
    }
    if (HiveService.getHuaweiOptOut()) {
      _isSignedIn = false;
      return false;
    }
    try {
      await _dataController!.readTodaySummation(DataType.DT_CONTINUOUS_STEPS_DELTA);
      _isSignedIn = true;
      return true;
    } catch (e) {
      debugPrint('HuaweiHealthService refreshSignInState error: $e');
      _isSignedIn = false;
      return false;
    }
  }

  /// Putuskan koneksi. Plugin `huawei_health` tidak menyediakan API sign-out
  /// (HealthAuth hanya punya signIn), jadi kita hanya bersihkan state lokal dan
  /// menandai opt-out supaya app berhenti memakai jalur Huawei sampai user
  /// connect ulang secara eksplisit.
  static Future<void> signOut() async {
    _isSignedIn = false;
    await HiveService.setHuaweiOptOut(true);
  }

  /// Baca semua metrik kesehatan hari ini dari Huawei Band.
  static Future<DailyMetricsModel?> fetchTodayMetrics() async {
    if (!_isInitialized || !_isSignedIn || _dataController == null) return null;

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      int? steps;
      int? calories;
      double? sleepHours;
      int? avgHeartRate;

      // 1. Langkah hari ini
      try {
        steps = await _readTodaySummation(DataType.DT_CONTINUOUS_STEPS_DELTA);
        await HiveService.saveDiagnosticsLog('[Huawei] Steps: $steps');
      } catch (e) {
        await HiveService.saveDiagnosticsLog('[Huawei] Steps error: $e');
      }

      // 2. Kalori hari ini
      try {
        calories = await _readTodaySummation(DataType.DT_CONTINUOUS_CALORIES_BURNT);
        await HiveService.saveDiagnosticsLog('[Huawei] Calories: $calories');
      } catch (e) {
        await HiveService.saveDiagnosticsLog('[Huawei] Calories error: $e');
      }

      // 3. Heart rate
      try {
        avgHeartRate = await _readAvgHeartRate(startOfDay, endOfDay);
        await HiveService.saveDiagnosticsLog('[Huawei] HR: $avgHeartRate');
      } catch (e) {
        await HiveService.saveDiagnosticsLog('[Huawei] HR error: $e');
      }

      // 4. Tidur
      try {
        sleepHours = await _readSleep(
          startOfDay.subtract(const Duration(hours: 4)),
          endOfDay.add(const Duration(hours: 12)),
        );
        await HiveService.saveDiagnosticsLog('[Huawei] Sleep: $sleepHours jam');
      } catch (e) {
        await HiveService.saveDiagnosticsLog('[Huawei] Sleep error: $e');
      }

      return DailyMetricsModel(
        sleepHours: sleepHours,
        steps: steps,
        calories: calories,
        averageHeartRate: avgHeartRate,
        date: DateTime.now(),
      );
    } catch (e) {
      await HiveService.saveDiagnosticsLog('[Huawei] fetchTodayMetrics error: $e');
      return null;
    }
  }

  /// Baca detak jantung terbaru (real-time) dari band.
  ///
  /// `readLatestData` mengembalikan titik data terakhir yang disinkronkan ke
  /// cloud Huawei — cocok untuk polling tiap ~30 detik saat jogging aktif.
  static Future<int?> fetchLatestHeartRate() async {
    if (!_isInitialized || !_isSignedIn || _dataController == null) return null;
    try {
      final Map<DataType, SamplePoint> result = await _dataController!.readLatestData(
        [DataType.DT_INSTANTANEOUS_HEART_RATE],
        packageName,
      );
      if (result.isEmpty) return null;
      final SamplePoint point = result.values.first;
      final values = point.fieldValues;
      if (values == null || values.values.isEmpty) return null;
      final val = values.values.first;
      if (val is num && val > 0) return val.toInt();
      return null;
    } catch (e) {
      debugPrint('HuaweiHealthService fetchLatestHeartRate error: $e');
      return null;
    }
  }

  /// Baca riwayat 7 hari untuk metrik tertentu.
  static Future<List<MapEntry<DateTime, double>>> fetch7DayHistory(String metricType) async {
    if (!_isInitialized || !_isSignedIn) {
      return List.generate(7, (i) => MapEntry(DateTime.now().subtract(Duration(days: 6 - i)), 0.0));
    }

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
              final s = await _readDailySummation(DataType.DT_CONTINUOUS_STEPS_DELTA, startOfDay);
              if (s != null && s > 0) value = s.toDouble();
            } catch (_) {}
            break;

          case 'calories':
            try {
              final c = await _readDailySummation(DataType.DT_CONTINUOUS_CALORIES_BURNT, startOfDay);
              if (c != null && c > 0) value = c.toDouble();
            } catch (_) {}
            break;

          case 'heartRate':
            try {
              final hr = await _readAvgHeartRate(startOfDay, endOfDay);
              if (hr != null && hr > 0) value = hr.toDouble();
            } catch (_) {}
            break;

          case 'sleep':
            try {
              final sl = await _readSleep(
                startOfDay.subtract(const Duration(hours: 4)),
                endOfDay.add(const Duration(hours: 12)),
              );
              if (sl != null && sl > 0) value = sl;
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

  // ── Private helpers ──────────────────────────────────────────────

  static Future<int?> _readTodaySummation(DataType dataType) async {
    try {
      final SampleSet? sampleSet = await _dataController!.readTodaySummation(dataType);
      if (sampleSet == null || sampleSet.samplePoints.isEmpty) return null;

      int total = 0;
      for (final point in sampleSet.samplePoints) {
        final values = point.fieldValues;
        if (values != null && values.isNotEmpty) {
          final firstVal = values.values.first;
          if (firstVal is num) {
            total += firstVal.toInt();
          }
        }
      }
      return total > 0 ? total : null;
    } catch (e) {
      debugPrint('readTodaySummation error: $e');
      return null;
    }
  }

  static Future<int?> _readDailySummation(DataType dataType, DateTime date) async {
    try {
      final yyyymmdd = date.year * 10000 + date.month * 100 + date.day;
      final List<SampleSet?>? sampleSets = await _dataController!.readDailySummationList(
        [dataType],
        yyyymmdd,
        yyyymmdd,
      );

      if (sampleSets == null || sampleSets.isEmpty) return null;

      int total = 0;
      for (final sampleSet in sampleSets) {
        if (sampleSet == null) continue;
        for (final point in sampleSet.samplePoints) {
          final values = point.fieldValues;
          if (values != null && values.isNotEmpty) {
            final firstVal = values.values.first;
            if (firstVal is num) {
              total += firstVal.toInt();
            }
          }
        }
      }
      return total > 0 ? total : null;
    } catch (e) {
      debugPrint('readDailySummation error: $e');
      return null;
    }
  }

  static Future<int?> _readAvgHeartRate(DateTime start, DateTime end) async {
    try {
      final dataCollector = DataCollector(
        dataType: DataType.DT_INSTANTANEOUS_HEART_RATE,
        dataGenerateType: DataGenerateType.DATA_TYPE_RAW,
        dataStreamName: 'HEART_RATE',
      );

      final readOptions = ReadOptions(
        dataCollectors: [dataCollector],
        startTime: start,
        endTime: end,
      );

      final ReadReply? reply = await _dataController!.read(readOptions);
      if (reply == null || reply.sampleSets.isEmpty) return null;

      int total = 0;
      int count = 0;
      for (final sampleSet in reply.sampleSets) {
        for (final point in sampleSet.samplePoints) {
          final values = point.fieldValues;
          if (values != null) {
            for (final val in values.values) {
              if (val is num && val > 0) {
                total += val.toInt();
                count++;
              }
            }
          }
        }
      }

      return count > 0 ? (total / count).round() : null;
    } catch (e) {
      debugPrint('readAvgHeartRate error: $e');
      return null;
    }
  }

  static Future<double?> _readSleep(DateTime start, DateTime end) async {
    try {
      final dataCollector = DataCollector(
        dataType: DataType.DT_CONTINUOUS_SLEEP,
        dataGenerateType: DataGenerateType.DATA_TYPE_RAW,
        dataStreamName: 'SLEEP',
      );

      final readOptions = ReadOptions(
        dataCollectors: [dataCollector],
        startTime: start,
        endTime: end,
      );

      final ReadReply? reply = await _dataController!.read(readOptions);
      if (reply == null || reply.sampleSets.isEmpty) return null;

      double totalMinutes = 0;
      for (final sampleSet in reply.sampleSets) {
        for (final point in sampleSet.samplePoints) {
          // Lewati fragmen "terjaga" (SLEEP_STATE = 4 per plugin sleep_state.dart:
          // 1=light, 2=REM, 3=deep, 4=awake). Tanpa filter ini jam tidur overcount
          // karena fragmen awake ikut dijumlahkan — baseline energi jadi salah.
          // Fallback aman: kalau field sleep_state tak ada, perilaku tetap seperti
          // sebelumnya (fragment ikut dihitung).
          if (point.fieldValues?['sleep_state'] == 4) continue;
          if (point.startTime != null && point.endTime != null) {
            final dur = point.endTime!.difference(point.startTime!);
            if (dur.inMinutes > 0) {
              totalMinutes += dur.inMinutes;
            }
          }
        }
      }

      return totalMinutes > 0 ? totalMinutes / 60.0 : null;
    } catch (e) {
      debugPrint('readSleep error: $e');
      return null;
    }
  }
}
