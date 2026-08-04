import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/health_service.dart';
import '../services/hive_service.dart';
import 'metrics_provider.dart';

enum HealthSyncStatus { idle, syncing, success, error, noPermission }

class HealthConnectState {
  final HealthSyncStatus status;
  final String? message;
  final DateTime? lastSync;

  const HealthConnectState({
    this.status = HealthSyncStatus.idle,
    this.message,
    this.lastSync,
  });

  HealthConnectState copyWith({
    HealthSyncStatus? status,
    String? message,
    DateTime? lastSync,
  }) {
    return HealthConnectState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

class HealthConnectNotifier extends Notifier<HealthConnectState> {
  @override
  HealthConnectState build() {
    return const HealthConnectState();
  }

  Future<bool> requestPermissions() async {
    final granted = await HealthService.requestPermissions();
    if (granted) {
      state = state.copyWith(
        status: HealthSyncStatus.idle,
        message: 'Izin diberikan',
      );
    } else {
      state = state.copyWith(
        status: HealthSyncStatus.noPermission,
        message: 'Izin ditolak. Buka Health Connect di HP Anda.',
      );
    }
    return granted;
  }

  Future<void> syncToday() async {
    state = state.copyWith(
      status: HealthSyncStatus.syncing,
      message: 'Menyinkronkan data...',
    );

    final metrics = await HealthService.fetchTodayMetrics();
    if (metrics == null) {
      state = state.copyWith(
        status: HealthSyncStatus.error,
        message: 'Gagal mengambil data kesehatan',
      );
      return;
    }

    await HiveService.saveMetrics(metrics);

    ref.invalidate(metricsProvider);

    state = state.copyWith(
      status: HealthSyncStatus.success,
      message: 'Data berhasil disinkronkan!',
      lastSync: DateTime.now(),
    );
  }

  Future<void> syncDateRange(DateTime start, DateTime end) async {
    state = state.copyWith(
      status: HealthSyncStatus.syncing,
      message: 'Menyinkronkan data riwayat...',
    );

    var current = start;
    int success = 0;
    int failed = 0;

    while (!current.isAfter(end)) {
      final metrics = await HealthService.fetchMetricsForDate(current);
      if (metrics != null) {
        await HiveService.saveMetrics(metrics);
        success++;
      } else {
        failed++;
      }
      current = current.add(const Duration(days: 1));
    }

    ref.invalidate(metricsProvider);

    state = state.copyWith(
      status: HealthSyncStatus.success,
      message: 'Sinkronisasi selesai. $success hari berhasil${failed > 0 ? ', $failed gagal' : ''}.',
      lastSync: DateTime.now(),
    );
  }
}

final healthConnectProvider =
    NotifierProvider<HealthConnectNotifier, HealthConnectState>(
  HealthConnectNotifier.new,
);
