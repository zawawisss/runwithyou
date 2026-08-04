# Progress & Task List

Terakhir diperbarui: 3 Agustus 2026

## Status Saat Ini

**Fase 1 (Setup & Fondasi) ✅ SELESAI**
- ✅ Pasang package inti: `flutter_riverpod`, `hive`, `hive_flutter`, `fl_chart`, `dio`, `go_router`
- ✅ Buat struktur folder bersih (`utils/`, `screens/`, `widgets/`, `models/`, `providers/`, `services/`)
- ✅ Konfigurasi sistem tema Soft Pink & Teal (`lib/utils/theme.dart`)
- ✅ Setup bottom navigation & screen placeholders

**Fase 2 (Dashboard & Data Mock) ✅ SELESAI**
- ✅ Integrasi data Hive lokal untuk langkah harian, tidur, kalori, dan heart rate.
- ✅ Inisialisasi data tiruan realistis saat database pertama kali dibuka.
- ✅ Implementasi perhitungan *Energy Level* dinamis yang terpengaruh oleh jam tidur, waktu berlalu, jadwal mengajar/les, dan tugas.
- ✅ Peningkatan visualisasi kartu energi dengan *Circular Progress Indicator* dan ikon petir.
- ✅ Menampilkan jadwal mengajar/les guru hari ini secara otomatis dari Hive.

**Fase 3 (Task Manager) ✅ SELESAI**
- ✅ Operasi CRUD tugas harian (Tambah, baca, ubah status centang, hapus).
- ✅ Bottom sheet interaktif untuk tambah tugas dengan rating petir (tingkat kesulitan 1-5).
- ✅ Penghapusan tugas modern dengan gerakan menggeser (*Swipe-to-dismiss*) dilengkapi SnackBar pembatalan (Undo).
- ✅ Rekomendasi tugas cerdas berdasarkan tingkat energi harian saat ini.
- ✅ Filter kategori tab (Semua, Mengajar, Les, Pribadi, Olahraga).

**Fase 4 (Jogging Tracker) ✅ SELESAI**
- ✅ Hitung durasi aktif, jarak simulasi/GPS, pace rata-rata, dan kalori yang terbakar.
- ✅ Menyediakan sakelar **Mode Simulasi** untuk memfasilitasi pengujian di web/emulator tanpa GPS fisik.
- ✅ Panel kontrol joging lengkap (Jeda/Lanjut/Berhenti dan Simpan).
- ✅ Penyimpanan data jogging otomatis memperbarui metrik langkah dan kalori harian di Beranda.
- ✅ Menampilkan daftar 3 olahraga joging terakhir di halaman tracking.

**Fase 7 (Progress & History - Grafik) ✅ SELESAI**
- ✅ Integrasi grafik batang `fl_chart` interaktif untuk langkah mingguan (7 hari terakhir).
- ✅ Pemberian warna batang dinamis (Batang mencapai target 8.000 langkah berwarna Teal, di bawah target berwarna Pink).
- ✅ Perhitungan akumulasi ringkasan mingguan (total langkah, kalori, streak hari aktif, jumlah workout).
- ✅ Halaman medali pencapaian (*badge*) interaktif.
- ✅ Rincian statistik all-time (total jarak km, total jam aktif, kalori, rata-rata pace).

**Fase 8 (Polish & Dark Mode) ✅ SELESAI**
- ✅ Mengubah MainScreen menjadi stateless `ConsumerWidget` dan memusatkan navigasi tab dengan `tabIndexProvider` sehingga tombol "Mulai Jogging" di Beranda dapat berpindah tab secara mulus.
- ✅ Mengintegrasikan `themeProvider` berbasis Riverpod dan Hive untuk menyimpan preferensi tema (Light/Dark).
- ✅ Mengubah warna kaku (`Colors.white` dan `AppColors.textPrimary`) di semua halaman menjadi adaptif terhadap `Theme.of(context)`.
- ✅ Bottom navigation bar melengkung dengan efek bayangan (shadow) premium.

**Fase 5 (Huawei Band / HMS Health Kit) 🔄 KODE SIAP — menunggu konfigurasi AGC dari user**
- ✅ `HuaweiHealthService` diperluas: `refreshSignInState()` (restore sesi tanpa layar login), `signOut()` (flag opt-out), `fetchLatestHeartRate()` (via `readLatestData`).
- ✅ Provider baru `huaweiHealthProvider` (sign-in/sign-out/sync, status terhubung) — `lib/providers/huawei_health_provider.dart`.
- ✅ Fallback auto-sync di `metricsProvider`: Huawei primer → Health Connect sekunder.
- ✅ HR real-time saat jogging via HMS (fallback Health Connect).
- ✅ Dialog "Huawei Band" di Profil ditulis ulang memakai provider; menampilkan status setup AGC.
- ✅ Konfigurasi build Android: plugin gradle `com.huawei.agconnect` 1.9.6.300 aktif otomatis saat `agconnect-services.json` ada; keep rules ProGuard; build tetap hijau tanpa file AGC.
- ⏳ **MENUNGGU USER**: daftar AppGallery Connect, buat project AGC, daftar SHA-256 keystore, unduh `agconnect-services.json` → `android/app/`, install HMS Core + login Huawei ID di HP (lihat `docs/huawei_setup.md`), lalu verifikasi end-to-end.

---

## Yang Belum Dikerjakan (Backlog)

### Fase 5: Huawei Watch Integration (Prioritas Sedang)
- [x] Integrasi SDK Huawei Health Kit di platform native Android (kode siap; menunggu setup AGC user).
- [~] Sinkronisasi data tidur, HR, langkah, dan kalori dari jam tangan Huawei (kode siap; SpO2 = lanjutan opsional).
- [x] Heart rate real-time saat olahraga (kode siap).
- [ ] Verifikasi end-to-end di HP Xiaomi setelah `agconnect-services.json` tersedia.

### Fase 6: AI Assistant (OpenRouter) (Prioritas Sedang)
- [ ] Hubungkan HTTP client Dio ke OpenRouter API.
- [ ] Implementasi prompt dinamis berbasis energi dan jadwal sibuk guru untuk rekomendasi olahraga personal.
- [ ] Fitur voice feedback / asisten personal.

---

## Catatan Teknis
- Pengujian visual browser headless Playwright dijalankan dalam mode rilis (`--release`) karena modus debug DDC tidak stabil pada upgrade WebSocket di lingkungan container.
- APK Android siap di-build untuk pengujian perangkat fisik: `flutter build apk --release`.
