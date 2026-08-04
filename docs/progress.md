# Progress & Task List

Terakhir diperbarui: 5 Agustus 2026

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

**Fase 5 (Huawei Band / HMS Health Kit) ❌ DIHAPUS (5 Agustus 2026)**
- ❌ Integrasi Huawei Health Kit (HMS) dihapus total: `HuaweiHealthService`, `huaweiHealthProvider`, dialog "Huawei Watch" di Profil, dependensi `huawei_health`, plugin gradle AGC, `agconnect-services.json`, dan `docs/huawei_setup.md`.
- ✅ Alasan: scope HR/sleep/real-time tertutup untuk developer individu (wajib enterprise), dan app Huawei Health tidak menulis ke Health Connect secara native.
- ✅ **Jalur baru:** Google Health Connect satu-satunya sumber data. Data Huawei Band masuk lewat bridge pihak ketiga **"Health Sync"** (Huawei Health → Health Connect) yang diinstal di HP.
- ✅ Setup di HP Fitri: aktifkan Cloud Huawei (Saya > Manajemen Privasi), install Health Sync, atur sumber Huawei Health → target Health Connect, izinkan akses.
- ⚠️ Trade-off: HR saat jogging mengikuti ritme sinkron bridge (bukan streaming real-time); cakupan data via bridge partial (SpO2 tidak tersedia).

---

## Yang Belum Dikerjakan (Backlog)

### Fase 5: Data Huawei Band via Health Connect Bridge ✅ (5 Agustus 2026)
- [x] Integrasi Huawei Health Kit (HMS) dihapus dari kode (keputusan: jalur enterprise tidak diambil).
- [x] Jalur data baru: Huawei Band → app Huawei Health → bridge "Health Sync" → Health Connect → aplikasi.
- [ ] Verifikasi end-to-end di HP Fitri setelah Health Sync diinstal & data band masuk ke Health Connect.

### Fase 6: AI Assistant (OpenRouter) (Prioritas Sedang)
- [ ] Hubungkan HTTP client Dio ke OpenRouter API.
- [ ] Implementasi prompt dinamis berbasis energi dan jadwal sibuk guru untuk rekomendasi olahraga personal.
- [ ] Fitur voice feedback / asisten personal.

---

## Catatan Teknis
- Pengujian visual browser headless Playwright dijalankan dalam mode rilis (`--release`) karena modus debug DDC tidak stabil pada upgrade WebSocket di lingkungan container.
- APK Android siap di-build untuk pengujian perangkat fisik: `flutter build apk --release`.
