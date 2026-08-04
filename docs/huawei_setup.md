# Panduan Setup Huawei Band (Phase 5 — HMS Health Kit)

> **Kenapa butuh ini?** App Huawei Health **tidak menulis data ke Google Health Connect secara native**
> (harus lewat app jembatan pihak ketiga yang manual/sebagian). Jadi satu-satunya cara native membaca
> data Huawei Band adalah **Huawei Health Kit langsung** — lewat SDK `huawei_health` yang sudah
> terintegrasi di kode app. SDK ini baca data dari **cloud Huawei** berdasarkan HUAWEI ID, jadi bisa
> jalan di HP Xiaomi selama HMS Core terpasang dan login dengan HUAWEI ID yang sama dengan app
> Huawei Health.

Kode Phase 5 sudah selesai. Yang tersisa adalah **setup eksternal di bawah ini yang hanya bisa kamu
kerjakan** (butuh akun dan identitasmu). Tidak perlu buru-buru: **build app tetap jalan** tanpa
langkah ini — integrasi HMS baru aktif setelah file `agconnect-services.json` ada.

---

## Ringkasan

| # | Langkah | Siapa |
|---|---------|-------|
| 1 | Daftar Huawei Developer (gratis) | Kamu |
| 2 | Buat project AppGallery Connect, nama paket `com.example.runwithyou` | Kamu |
| 3 | Daftarkan SHA-256 sidik jari keystore | Kamu |
| 4 | Aktifkan **Health Kit** + **Account Kit**, unduh `agconnect-services.json` → `android/app/` | Kamu |
| 5 | Di HP Xiaomi: install **HMS Core**, login HUAWEI ID (sama dengan app Huawei Health) | Kamu |
| 6 | Build APK, install, verifikasi di app | Bersama |

---

## Langkah 1 — Daftar Huawei Developer

1. Buka https://developer.huawei.com/consumer/en/ → **Register** / **Sign up**.
2. Daftar dengan email (atau HUAWEI ID), verifikasi email. Gratis.
3. Jika diminta verifikasi identitas tambahan untuk layanan tertentu, selesaikan sesuai petunjuk.

## Langkah 2 — Buat project & app di AppGallery Connect (AGC)

1. Buka konsol AGC: https://developer.huawei.com/consumer/en/service/josp/agc/index.html
2. **My projects → Add project** → beri nama (mis. `RunWithYou`).
3. Masuk project → **Add app**:
   - Platform: **Android**
   - Nama app: `RunWithYou`
   - **Nama paket: `com.example.runwithyou`** — harus PERSIS sama dengan `applicationId` di
     `android/app/build.gradle.kts`. Kalau beda, Health Kit gagal (kode error 50002).
4. Simpan.

## Langkah 3 — Daftarkan SHA-256 sidik jari keystore

Health Kit / Account Kit butuh sidik jari sertifikat signing app.

1. Buka file `android/key.properties` (jangan dicommit) untuk melihat `storeFile` (jalur ke keystore).
2. Jalankan di terminal (ganti `<jalur-keystore>` dengan isi `storeFile`):
   ```bash
   keytool -list -v -keystore <jalur-keystore> -alias <keyAlias>
   ```
   (akan diminta password — isi `storePassword` dari `key.properties`)
3. Salin nilai **SHA256** (40 karakter hex, tanpa spasi).
4. Di AGC: halaman app → **Grow → App Services → Account Kit** → daftarkan SHA-256 tadi.
   Atau di **Project settings → General info** jika formulirnya tersedia.

## Langkah 4 — Aktifkan layanan & unduh agconnect-services.json

1. Di AGC halaman app, aktifkan:
   - **Account Kit** (untuk login HUAWEI ID).
   - **Health Kit** (untuk baca data kesehatan). Jika diminta, pilih data yang dipakai app:
     langkah, detak jantung, tidur, kalori, jarak, aktivitas.
2. Kembali ke **Project settings → General info** → klik **agconnect-services.json** → **Download**.
3. Letakkan file di folder: **`android/app/agconnect-services.json`**
   (satu folder dengan `build.gradle.kts`).

> Setelah file ini ada, build berikutnya otomatis mengaktifkan integrasi HMS (plugin gradle AGC
> 1.9.6.300 diaplikasikan otomatis). Tidak perlu mengubah kode apa pun.

## Langkah 5 — Siapkan HP Xiaomi

1. Pastikan band sudah ter-pair dengan **app Huawei Health** di HP (data mengalir ke cloud Huawei).
2. Install **HMS Core** (Huawei Mobile Services) di HP Xiaomi:
   - Cara mudah: buka app **Huawei Health** → jika diminta install HMS Core, ikuti.
   - Atau unduh **AppGallery** lalu instal HMS Core dari sana.
3. Di HMS Core (atau di app Huawei Health), **login dengan HUAWEI ID yang SAMA** dengan yang
   dipakai band. Izin data kesehatan akan diminta saat pertama kali app RunWithYou connect.

## Langkah 6 — Build & verifikasi

1. Build APK rilis: `flutter build apk --release`
2. Install di HP Xiaomi: `flutter install` atau salin `build/app/outputs/flutter-apk/app-release.apk`.
3. Buka app → tab **Profil** → **Huawei Watch**:
   - Status seharusnya menampilkan instruksi login (bukan lagi "Integrasi HMS belum aktif").
   - Tekan **Hubungkan Huawei Band** → login HUAWEI ID → izinkan akses data.
   - Tekan **Sync dari Huawei Band** → bandingkan langkah/HR/tidur dengan nilai di app Huawei Health.
4. Cek detail error di **Health Connect → Lihat Log Diagnostik** (baris `[Huawei] ...`).
5. Restart app → status tetap "terhubung" tanpa login ulang.

---

## Troubleshooting

| Gejala | Penyebab umum | Solusi |
|--------|---------------|--------|
| "Integrasi HMS belum aktif" di dialog | `agconnect-services.json` belum ada di `android/app/` | Selesaikan Langkah 4 |
| Sign-in gagal | HMS Core belum terpasang / HUAWEI ID belum login | Langkah 5 |
| Sync gagal / data kosong | HUAWEI ID beda dengan yang dipakai band | Pakai HUAWEI ID yang sama |
| Error **50002** | Nama paket AGC ≠ `applicationId` app | Samakan dengan `com.example.runwithyou` |
| Baca data gagal di build **release** | R8/Gson TypeToken | Keep rules sudah ditambahkan di `android/app/proguard-rules.pro` |
| Perangkat tanpa HMS Core (device non-Android) | HMS tidak tersedia | Jalur Huawei otomatis nonaktif; app tetap pakai Health Connect |

## Catatan

- **Ganti nama paket?** `com.example.runwithyou` adalah placeholder. Sebaiknya ganti `applicationId`
  **sebelum** publikasi ke Google Play (`com.example.*` tidak diizinkan Play). Jika diganti, project AGC
  harus dibuat ulang / nama paketnya diubah, dan `agconnect-services.json` diunduh ulang.
- **SpO2 & kalori sesi:** `readLatestData` sudah mendukung SpO2 dan pencatatan workout native Huawei
  (`ActivityRecordsController`) — direncanakan sebagai lanjutan opsional.
- Plugin `huawei_health` tidak menyediakan API sign-out; tombol "Putuskan Koneksi" hanya mematikan
  jalur Huawei di app (flag opt-out), sesi HUAWEI ID tetap otorisasi di HMS Core.
