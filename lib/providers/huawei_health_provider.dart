import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/huawei_health_service.dart';
import '../services/hive_service.dart';
import 'metrics_provider.dart';

enum HuaweiStatus { idle, signingIn, signedIn, signedOut, syncing, error }

class HuaweiHealthState {
  final HuaweiStatus status;
  final String? message;
  final DateTime? lastSync;
  final bool isInitialized;
  final bool isSignedIn;

  const HuaweiHealthState({
    this.status = HuaweiStatus.idle,
    this.message,
    this.lastSync,
    this.isInitialized = false,
    this.isSignedIn = false,
  });

  HuaweiHealthState copyWith({
    HuaweiStatus? status,
    String? message,
    DateTime? lastSync,
    bool? isInitialized,
    bool? isSignedIn,
  }) {
    return HuaweiHealthState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSync: lastSync ?? this.lastSync,
      isInitialized: isInitialized ?? this.isInitialized,
      isSignedIn: isSignedIn ?? this.isSignedIn,
    );
  }
}

/// Controller status koneksi Huawei Band — pola meniru [healthConnectProvider].
///
/// Baca state via `ref.watch(huaweiHealthProvider)`, side-effect via
/// `ref.read(huaweiHealthProvider.notifier).someMethod()`.
class HuaweiHealthNotifier extends Notifier<HuaweiHealthState> {
  @override
  HuaweiHealthState build() {
    // Status sinkron dengan service. Sesi HMS Core sudah di-probe di main()
    // lewat HuaweiHealthService.refreshSignInState(), jadi tidak perlu login ulang.
    final initialized = HuaweiHealthService.isInitialized;
    final signedIn = HuaweiHealthService.isSignedIn;
    return HuaweiHealthState(
      status: initialized ? (signedIn ? HuaweiStatus.signedIn : HuaweiStatus.signedOut) : HuaweiStatus.idle,
      isInitialized: initialized,
      isSignedIn: signedIn,
    );
  }

  /// Probe ulang status sign-in (dipakai saat dialog dibuka / pasca-restart).
  Future<void> refresh() async {
    final signedIn = await HuaweiHealthService.refreshSignInState();
    state = HuaweiHealthState(
      status: signedIn ? HuaweiStatus.signedIn : HuaweiStatus.signedOut,
      isInitialized: HuaweiHealthService.isInitialized,
      isSignedIn: signedIn,
    );
  }

  Future<bool> signIn() async {
    if (!HuaweiHealthService.isInitialized) {
      state = state.copyWith(
        status: HuaweiStatus.error,
        message: 'Integrasi HMS belum aktif. Konfigurasi AppGallery Connect '
            '(agconnect-services.json) diperlukan — lihat docs/huawei_setup.md.',
      );
      return false;
    }

    state = state.copyWith(status: HuaweiStatus.signingIn, message: 'Menghubungkan ke Huawei Band...');
    final success = await HuaweiHealthService.signIn();
    if (success) {
      state = HuaweiHealthState(
        status: HuaweiStatus.signedIn,
        message: 'Huawei Band berhasil terhubung!',
        isInitialized: true,
        isSignedIn: true,
      );
      return true;
    }
    state = state.copyWith(
      status: HuaweiStatus.error,
      message: 'Gagal menghubungkan. Pastikan app HMS Core terpasang dan Anda '
          'login dengan Huawei ID yang sama dengan app Huawei Health.',
    );
    return false;
  }

  Future<void> signOut() async {
    await HuaweiHealthService.signOut();
    state = state.copyWith(
      status: HuaweiStatus.signedOut,
      isSignedIn: false,
      message: 'Koneksi diputuskan',
    );
  }

  Future<void> syncToday() async {
    if (!HuaweiHealthService.isSignedIn) {
      state = state.copyWith(status: HuaweiStatus.signedOut, message: 'Belum terhubung ke Huawei Band');
      return;
    }

    state = state.copyWith(status: HuaweiStatus.syncing, message: 'Menyinkronkan dari Huawei Band...');
    final metrics = await HuaweiHealthService.fetchTodayMetrics();
    if (metrics == null) {
      state = state.copyWith(
        status: HuaweiStatus.error,
        message: 'Gagal mengambil data dari Huawei Band',
      );
      return;
    }

    await HiveService.saveMetrics(metrics);
    ref.invalidate(metricsProvider);

    state = state.copyWith(
      status: HuaweiStatus.signedIn,
      message: 'Data berhasil disinkronkan dari Huawei Band!',
      lastSync: DateTime.now(),
    );
  }
}

final huaweiHealthProvider =
    NotifierProvider<HuaweiHealthNotifier, HuaweiHealthState>(
  HuaweiHealthNotifier.new,
);
