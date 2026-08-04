import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_metrics.dart';
import '../services/hive_service.dart';
import '../services/health_service.dart';
import '../services/huawei_health_service.dart';

class MetricsNotifier extends Notifier<DailyMetricsModel> {
  Timer? _autoSyncTimer;

  @override
  DailyMetricsModel build() {
    ref.onDispose(() {
      _autoSyncTimer?.cancel();
    });

    final cached = HiveService.getMetricsForDate(DateTime.now());

    // Sync once immediately on first build
    _trySyncFromHealth();

    // Then sync every 10 minutes to match Health Connect's write cadence
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _trySyncFromHealth();
    });

    return cached;
  }

  Future<void> _trySyncFromHealth() async {
    try {
      // Huawei primer bila terhubung, fallback ke Health Connect (Google).
      // App Huawei Health tidak menulis ke Health Connect secara native, jadi
      // tanpa jalur Huawei ini data Huawei Band tidak akan pernah masuk ke app.
      var metrics = HuaweiHealthService.isSignedIn
          ? await HuaweiHealthService.fetchTodayMetrics()
          : null;
      metrics ??= await HealthService.fetchTodayMetrics();

      if (metrics != null) {
        state = metrics;
        await HiveService.saveMetrics(metrics);
      }
    } catch (_) {}
  }

  Future<void> updateMetrics({
    double? sleepHours,
    int? steps,
    int? calories,
    int? averageHeartRate,
  }) async {
    final updated = state.copyWith(
      sleepHours: sleepHours,
      steps: steps,
      calories: calories,
      averageHeartRate: averageHeartRate,
    );
    state = updated;
    await HiveService.saveMetrics(updated);
  }

  Future<void> refresh() async {
    state = HiveService.getMetricsForDate(DateTime.now());
    await _trySyncFromHealth();
  }
}

final metricsProvider = NotifierProvider<MetricsNotifier, DailyMetricsModel>(MetricsNotifier.new);
