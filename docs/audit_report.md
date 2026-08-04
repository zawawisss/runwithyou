# Laporan Audit Project RunWithYou

**Tanggal:** 31 Juli 2026
**Metode:** 6 sub-agent paralel (structure, architecture, state management, Hive, UI, services)
**Total file Dart:** 28 | **Total baris:** 7.577

> **NOTA (5 Agustus 2026):** Integrasi Huawei Health Kit (HMS) telah **dihapus** dari kode. Semua referensi `HuaweiHealthService`, `huawei_health_provider`, dan HMS Health Kit di bawah ini bersifat historis (audit ditulis 31 Juli 2026) dan tidak lagi berlaku. Data kesehatan sekarang hanya dari Google Health Connect; data Huawei Band masuk lewat bridge pihak ketiga "Health Sync".

---

## Daftar Isi

1. [Ringkasan Eksekutif](#1-ringkasan-eksekutif)
2. [Struktur Project & File](#2-struktur-project--file)
3. [Arsitektur & Dependency Graph](#3-arsitektur--dependency-graph)
4. [State Management (Riverpod)](#4-state-management-riverpod)
5. [Hive Persistence Layer](#5-hive-persistence-layer)
6. [Model Layer](#6-model-layer)
7. [Service Layer](#7-service-layer)
8. [Health Sync Architecture](#8-health-sync-architecture)
9. [UI Screens](#9-ui-screens)
10. [Theme & Styling](#10-theme--styling)
11. [Build & Config](#11-build--config)
12. [Daftar Masalah Lengkap](#12-daftar-masalah-lengkap)
13. [Rekomendasi](#13-rekomendasi)

---

## 1. Ringkasan Eksekutif

RunWithYou adalah Flutter fitness + task manager untuk guru bernama Fitri. Bahasa Indonesia, Android-first, Material 3. Menggunakan Riverpod untuk state management, Hive untuk local persistence, Google Health Connect dan Huawei Health Kit untuk data kesehatan.

**Kekuatan:**
- State management Riverpod sangat konsisten -- zero anti-pattern violations
- Health Connect integration komprehisif (steps, sleep, HR, calories)
- Merge logic di saveMetrics() benar preservasi data existing
- Energy calculation (energyProvider) adalah derived provider yang well-designed
- Diagnostic logging yang mendalam di HealthService

**Kelemahan:**
- Race condition di concurrent Hive writes
- Silent error swallowing di semua services
- Dead code (HuaweiHealthService, go_router)
- Screen files terlalu besar karena tidak ada widget extraction
- AI Chat belum terhubung ke backend
- Error handling yang lemah di beberapa service kritis

---

## 2. Struktur Project & File

### 2.1 Peta File Source

```
lib/
├── main.dart                         (168 baris)
├── models/
│   ├── daily_metrics.dart            (51 baris)
│   ├── note.dart                     (45 baris)
│   ├── task.dart                     (91 baris)
│   └── workout.dart                  (63 baris)
├── providers/
│   ├── ai_chat_provider.dart         (51 baris)
│   ├── energy_provider.dart          (138 baris)
│   ├── health_connect_provider.dart  (114 baris)
│   ├── jogging_provider.dart         (272 baris)
│   ├── metrics_provider.dart         (63 baris)
│   ├── notes_provider.dart           (39 baris)
│   ├── profile_provider.dart         (49 baris)
│   ├── tab_provider.dart             (12 baris)
│   ├── tasks_provider.dart           (61 baris)
│   ├── theme_provider.dart           (27 baris)
│   └── workout_provider.dart         (22 baris)
├── screens/
│   ├── ai_chat_screen.dart           (78 baris)
│   ├── dashboard_screen.dart         (1.159 baris)
│   ├── jogging_screen.dart           (560 baris)
│   ├── profile_screen.dart           (1.201 baris)
│   ├── progress_screen.dart          (555 baris)
│   └── tasks_screen.dart             (1.325 baris)
├── services/
│   ├── health_service.dart           (431 baris)
│   ├── hive_service.dart             (319 baris)
│   ├── huawei_health_service.dart    (313 baris)
│   ├── notification_service.dart     (120 baris)
│   └── nvidia_service.dart           (124 baris)
├── utils/
│   └── theme.dart                    (126 baris)
└── widgets/                          (KOSONG)
```

### 2.2 Breakdown per Layer

| Layer | File | Total Baris | % Kode |
|---|---|---|---|
| screens/ | 6 | 4.878 | 64% |
| services/ | 5 | 1.307 | 17% |
| providers/ | 11 | 849 | 11% |
| models/ | 4 | 250 | 3% |
| utils/ | 1 | 126 | 2% |
| main.dart | 1 | 168 | 2% |
| **Total** | **28** | **7.577** | |

Screens mendominasi karena `lib/widgets/` kosong -- semua widget UI inline di dalam screen files.

### 2.3 File yang Tidak Seharusnya Ada di Repo

| File | Masalah |
|---|---|
| `android/key.properties` | Password keystore plaintext (`runwithyou7`) -- SECURITY RISK |
| `._Screenshot 2026-07-26 at 10.25.25.png` | macOS resource fork, harusnya di-gitignore |
| `data_layer_analysis.md` | Generated analysis dari session sebelumnya, bukan source code |
| `README.md` | Masih boilerplate default Flutter ("A new Flutter project") |
| `screenshots/` | Directory kosong |
| `lib/widgets/` | Directory kosong |

### 2.4 Dependency Unused

| Package | Status |
|---|---|
| `go_router ^17.3.0` | Dideclare di pubspec.yaml, **tidak di-import atau dipakai** di manapun |
| `huawei_health ^6.17.0+300` | Di-import di `huawei_health_service.dart`, tapi service hanya di-init, **tidak pernah dipanggil** dari UI atau provider |

---

## 3. Arsitektur & Dependency Graph

### 3.1 Inisialisasi (main.dart)

Urutan inisialisasi di `main()`:
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `HiveService.init()` -- buka 5 box, seed data
3. `HealthService.init()` -- konfigurasi Health Connect
4. `HuaweiHealthService.init()` -- inisialisasi HMS DataController (**dead code**)
5. `NotificationService.init()` -- inisialisasi flutter_local_notifications
6. `NotificationService.requestPermission()`
7. `runApp(ProviderScope(child: RunWithYouApp()))`

### 3.2 Dependency Graph (Tidak Ada Circular)

```
Models (zero dependencies)
    ���
Services (depend on external packages only)
    ↓
Providers (depend on models + services + other providers -- acyclic)
    ↓
Screens (depend on providers + widgets)
    ↓
main.dart (depends on everything)
```

**Provider dependency graph:**
```
metricsProvider ──────┐
                      ├─→ energyProvider (derived, watches both)
tasksProvider ────────┘
                      ↑
healthConnectProvider → invalidates metricsProvider after sync

joggingProvider → reads workoutProvider + metricsProvider

workoutProvider ← joggingProvider writes to it

themeProvider    → reads/writes Hive directly (bypasses HiveService)
profileProvider  → reads/writes Hive directly (bypasses HiveService)
```

### 3.3 Navigation

- 5 tab bottom navigation via `tabIndexProvider` (index swap, bukan `IndexedStack`)
- AI Chat diakses via `Navigator.push` dari FAB
- `go_router` ada di dependencies tapi tidak dipakai

---

## 4. State Management (Riverpod)

### 4.1 Inventaris Provider

| Provider | Tipe | State Type | Pola |
|---|---|---|---|
| `tabIndexProvider` | `NotifierProvider<TabIndexNotifier, int>` | `int` | Custom setter |
| `themeProvider` | `NotifierProvider<ThemeNotifier, ThemeMode>` | `ThemeMode` | Hive-backed |
| `workoutProvider` | `NotifierProvider<WorkoutNotifier, List<WorkoutModel>>` | `List<WorkoutModel>` | Hive-backed CRUD |
| `notesProvider` | `NotifierProvider<NotesNotifier, List<NoteModel>>` | `List<NoteModel>` | Hive-backed CRUD |
| `profileProvider` | `NotifierProvider<ProfileNotifier, ProfileState>` | `ProfileState` | Hive direct access |
| `tasksProvider` | `NotifierProvider<TasksNotifier, List<TaskModel>>` | `List<TaskModel>` | Hive-backed CRUD |
| `metricsProvider` | `NotifierProvider<MetricsNotifier, DailyMetricsModel>` | `DailyMetricsModel` | Async health sync + timer |
| `healthConnectProvider` | `NotifierProvider<HealthConnectNotifier, HealthConnectState>` | `HealthConnectState` | Manual sync controller |
| `aiChatProvider` | `NotifierProvider<AiChatNotifier, List<ChatMessage>>` | `List<ChatMessage>` | In-memory only |
| `joggingProvider` | `NotifierProvider<JoggingNotifier, JoggingSessionState>` | `JoggingSessionState` | State machine |
| `energyProvider` | `Provider<EnergyStatus>` | `EnergyStatus` | **Derived** (computed) |

### 4.2 Konvensi: ref.read vs ref.watch

**Verdik: SANGAT KONSISTEN -- zero violations di seluruh codebase.**

- `ref.watch(...)` -- 16 occurrences, semua di `build()` methods
- `ref.read(...)` -- 21 occurrences, semua di callbacks (onPressed, onTap, onRefresh, dll)
- `ref.invalidate(...)` -- 8 occurrences, di pull-to-refresh dan post-sync refresh

### 4.3 Verifikasi Pattern per Provider

**energyProvider (Derived Provider):**
- Watches `metricsProvider` (sleepHours) + `tasksProvider` (task effects)
- Pure computation, zero side-effects -- textbook derived provider
- Recomputes otomatis saat upstream berubah

**metricsProvider (Auto-Sync Timer):**
- `build()` load cached data dari Hive, lalu `_trySyncFromHealth()` + `Timer.periodic(10 menit)`
- Timer di-cancel via `ref.onDispose()` -- prevent leaks
- **Masalah:** `catch (_) {}` menelan error tanpa logging

**joggingProvider (State Machine):**
- States: idle → active → paused → idle
- 1-second timer, setiap 30 ticks poll Health Connect untuk HR dan calories
- GPS via `Geolocator.getPositionStream` (3m filter, 30m/s noise filter)
- Timer dan GPS subscription di-cancel via `ref.onDispose()`
- **Masalah:** `.listen()` tanpa `onError` -- GPS error = tracking mati tanpa notif

**tabIndexProvider:**
- Custom `set state` override untuk mutate state dari luar
- Bekerja tapi unconventional -- lebih idiomatis pakai `setTab(int value)`

### 4.4 Provider Consumption Map

| Screen | ref.watch | ref.read | ref.invalidate |
|---|---|---|---|
| main.dart | themeProvider, tabIndexProvider | healthConnectProvider.notifier, tabIndexProvider.notifier | -- |
| dashboard_screen | metrics, energy, tasks, profile, notes, healthConnect | healthConnect.notifier, tabIndex.notifier, notes.notifier | metrics, energy, tasks, notes |
| tasks_screen | tasks, energy | tasks.notifier | tasks, energy |
| jogging_screen | jogging, workout | jogging.notifier | -- |
| progress_screen | workout, profile | -- | -- |
| profile_screen | theme, profile, healthConnect | theme.notifier, profile.notifier, healthConnect.notifier | -- |
| ai_chat_screen | -- | -- | -- |

### 4.5 Masalah State Management

1. **aiChatProvider tidak terhubung ke backend** -- `sendMessage()` hanya append ke local state. Screen cuma placeholder "Segera Hadir". Provider tidak di-import atau digunakan di manapun.

2. **progress_screen.dart bypass provider** -- Baca Hive langsung via `HiveService.getAllMetrics()` dan `HiveService.getMetricsForDate()` di dalam `build()`. Data bisa stale karena provider tidak diinvalidate setelah sync historikal.

3. **Tab switch rebuild semua screen** -- Tidak pakai `IndexedStack`, jadi scroll position hilang saat pindah tab dan `initState` dijalankan ulang.

---

## 5. Hive Persistence Layer

### 5.1 Box Inventory

| Box Name | Purpose | Key Type |
|---|---|---|
| `tasks_box` | Task records | String (task ID) |
| `workouts_box` | Workout records | String (workout ID) |
| `metrics_box` | Daily health metrics | String (`YYYY-MM-DD`) |
| `settings_box` | Heterogeneous settings | String (various keys) |
| `notes_box` | User notes | String (note ID) |

### 5.2 settings_box Key Map

| Key | Type | Writer | Reader |
|---|---|---|---|
| `profile_name` | `String` | HiveService.init + ProfileNotifier | ProfileNotifier |
| `step_goal` | `int` | HiveService.init + ProfileNotifier | ProfileNotifier |
| `theme_mode` | `String` | ThemeNotifier | ThemeNotifier |
| `nvidia_api_key` | `String` | HiveService + tasks_screen | HiveService + tasks_screen |
| `diagnostics_logs` | `List<String>` | HiveService | HiveService |

**Masalah:** `ThemeNotifier` dan `ProfileNotifier` akses Hive langsung dengan hardcoded string `'settings_box'` -- seharusnya lewat `HiveService` untuk encapsulation.

### 5.3 Merge Logic di saveMetrics()

```
Existing data: steps=5000
New fetch:     steps=null
Result:        steps=5000 (preserved)

Existing data: steps=5000
New fetch:     steps=3000
Result:        steps=3000 (overwritten with new non-zero)

Existing data: steps=5000
New fetch:     steps=0
Result:        steps=5000 (zero treated as "no data", preserved)
```

**Verdik:** Logic benar untuk domain Health Connect, tapi zero-value tidak bisa di-re-store secara eksplisit.

### 5.4 Seeding Logic

- Kondisi: `tasksBox.isEmpty && notesBox.isEmpty` (compound guard)
- 7 tasks (2 recurring + 5 one-off), 3 notes, 2 settings (profile_name, step_goal)
- Task IDs hardcoded: `s1`, `s2`, `t1`-`t5`
- Historical metrics dan workouts TIDAK di-seed

### 5.5 Race Condition (Severity: MEDIUM)

`HiveService.saveMetrics()` melakukan read-then-write yang **tidak atomic**. Tiga concurrent callers:
1. `metricsProvider._trySyncFromHealth()` -- 10 menit timer
2. `HealthConnectNotifier.syncToday()` -- saat app launch
3. `JoggingNotifier.stopAndSaveSession()` -- saat jog selesai

Kalau dua callers target tanggal yang sama secara simultan, last-writer-wins bisa menyebabkan data loss.

### 5.6 Masalah Lain

| Masalah | Severity |
|---|---|
| `progress_screen.dart` lakukan synchronous Hive reads di `build()` | Low-Medium |
| `copyWith()` di DailyMetricsModel tidak bisa reset field ke null | Low |
| `ThemeNotifier` dan `ProfileNotifier` bypass HiveService | Low |
| Tidak ada try-catch di `Hive.openBox()` -- corrupted storage = unrecoverable | Low |
| Tidak ada TypeAdapters -- semua model pakai Map serialization | Info |
| Duplicate comment di line 42 hive_service.dart | Trivial |

---

## 6. Model Layer

### 6.1 TaskModel

- 10 fields: id, title, description, isCompleted, date, category, energyRequired, timeOfDay, startTime?, endTime?, isRecurring
- Boolean diserialisasi sebagai int 0/1 untuk Hive
- `fromMap()` defensif: handle both `== 1` dan `== true`
- `copyWith()` punya `clearStartTime`/`clearEndTime` flags untuk explicit nulling
- `hasTime` getter: true jika startTime AND endTime keduanya set

### 6.2 DailyMetricsModel

- Semua field nullable kecuali `date`
- `toMap()` simpan null langsung sebagai null
- `fromMap()` pakai nullable casts (`as int?`, `as num?`) -- paling defensif
- Tidak bisa reset field ke null setelah non-null (standard Dart limitation)

### 6.3 WorkoutModel

- id = `DateTime.now().millisecondsSinceEpoch.toString()`
- distance (km double), duration (seconds int), calories, averagePace (String MM:SS), averageHeartRate
- `fromMap()` pakai `(map['distance'] as num).toDouble()` -- good defensive cast
- Tidak ada nullable fields

### 6.4 NoteModel

- id, content, colorIndex (0-4), date
- Paling sederhana, no booleans, no nullables
- toMap/fromMap symmetric dan correct

### 6.5 Masalah Model

| Masalah | Severity |
|---|---|
| `NoteModel` dan `WorkoutModel` fromMap() tidak ada null guard -- runtime error jika field hilang | Low |
| DateTime ISO string bisa menyimpan timezone offset -- date-key mismatch jika timezone berubah | Low |
| TaskModel ID berbasis timestamp -- collision jika beberapa task dibuat dalam milliseconds yang sama | Low |

---

## 7. Service Layer

### 7.1 HiveService (319 baris) -- Aktif

**Public API:** `init()`, CRUD untuk tasks/workouts/metrics/notes, API key management, diagnostics log

- 5 boxes dengan 4 private helper getters
- `_formatDateKey()` menghasilkan `YYYY-MM-DD` dari `DateTime.now()`
- Diagnostics log: timestamp `HH:mm:ss`, cap 100 entries, prepend (newest first)

**Masalah:**
- `saveMetrics()` tidak atomic (lihat §5.5)
- Tidak ada `_getSettingsBox()` -- settings diakses dengan raw `Hive.box()`

### 7.2 HealthService (431 baris) -- Aktif

**Public API:** `init()`, `requestPermissions()`, `fetchTodayMetrics()`, `fetchMetricsForDate()`, `fetchLatestHeartRate()`, `fetchCaloriesInInterval()`, `fetchStepsInInterval()`

**Kekuatan:**
- Comprehensive metric coverage: steps, HR, sleep (session + stages: deep/light/REM), calories (active → total → basal fallback)
- Extensive diagnostic logging via `HiveService.saveDiagnosticsLog()`
- Sleep window diperluas (4h sebelum midnight sampai noon)

**Masalah:**
- **Semua error silently swallowed** -- setiap `catch (_)` return null tanpa logging
- `requestPermissions()` menelan error -- bisa salah interpretasi sebagai "ditolak"
- Tidak ada caching permissions state -- setiap auto-sync buat native bridge call
- Tidak ada rate limiting -- concurrent callers bisa overlap

### 7.3 HuaweiHealthService (313 baris) -- DEAD CODE

**Status:** Di-init di `main.dart` tapi **tidak pernah dipanggil** dari provider atau screen manapun.

**Implementasi:**
- `signIn()`, `fetchTodayMetrics()`, `fetch7DayHistory()` sudah ditulis
- API mirror HealthService (steps, HR, calories, sleep)
- `signIn()` tidak pernah dipanggil → `_isSignedIn` selalu false → `fetchTodayMetrics()` selalu return null

**Masalah:**
- Waste startup time (~ratusan ms untuk HMS Core init)
- Waste APK size (HMS Health Kit dependency tanpa conditional)
- `_readAvgHeartRate()` hitung field values, bukan measurements -- bisa skew average

### 7.4 NotificationService (120 baris) -- Aktif

**Public API:** `init()`, `requestPermission()`, `scheduleTaskNotification()`, `scheduleDailyNotification()`, `cancel()`

**Masalah:**
- **Timezone tidak di-set:** `tz.initializeTimeZones()` tanpa `tz.setLocalLocation()` -- bisa default ke UTC
- **Negative time edge case:** `scheduleTaskNotification` kurangi advanceMinutes dari waktu, bisa result waktu negatif yang bergulir ke hari sebelumnya. Return `-1` tapi caller tidak distinguish dari valid ID
- **`scheduleDailyNotification` tanpa past-time guard** -- bisa fire langsung jika waktu sudah lewat
- **No `onDidReceiveNotificationResponse`** -- tap notification tidak melakukan apa-apa
- ID collision: `DateTime.now().millisecondsSinceEpoch.remainder(100000)` -- range 0-99999, no collision detection

### 7.5 NvidiaService (124 baris) -- Aktif

**Public API:** `chat()` untuk NVIDIA NIM API (Llama 3.1 70B), `parseTasks()` untuk WhatsApp text parsing

**Masalah:**
- **Dio() tanpa timeout** -- API hanging = UI freeze
- **New Dio instance setiap call** -- no connection pooling
- **No retry logic** -- 429/503 langsung error ke user
- **API key plain text** di memory (`static String? _apiKey`)
- **ID collision** -- `DateTime.now().millisecondsSinceEpoch` untuk task IDs dari AI parse
- **Silent energy clamping** -- `clamp(1, 5)` adjust out-of-range values tanpa feedback
- **Hardcoded system prompt** -- "Langsung JSON aja" -- kurang robust

---

## 8. Health Sync Architecture

### 8.1 Tiga Sync Path

```
Path 1: metricsProvider._trySyncFromHealth()
  └─ Setiap 10 menit (Timer.periodic)
  └─ HealthService.fetchTodayMetrics()
  └─ State update + Hive save

Path 2: HealthConnectNotifier.syncToday()
  └─ Sekali saat app launch (MainScreen.initState)
  └─ HealthService.fetchTodayMetrics()
  └─ Hive save + invalidate metricsProvider

Path 3: JoggingNotifier._syncRealTimeHealthData()
  └─ Setiap 30 detik saat jogging aktif
  └─ HealthService.fetchLatestHeartRate() + fetchCaloriesInInterval()
  └─ Partial state update
```

### 8.2 Data Flow

```
HealthService.fetchTodayMetrics()
    ↓
HiveService.saveMetrics()  ← merge logic (preserve existing non-null)
    ↓
metricsProvider.state = new metrics
    ↓
energyProvider recomputes (watches metricsProvider)
    ↓
UI rebuilds
```

### 8.3 Masalah Redundansi

- Path 1 dan 2 berjalan bersamaan saat app launch
- Keduanya fetch dari HealthService dan tulis ke Hive
- `HiveService.saveMetrics()` tidak atomic -- concurrent writes bisa saling overwrite
- JoggingProvider `stopAndSaveSession()` baca lalu tulis `metricsProvider` -- auto-sync bisa fires di antaranya (stale read race)

### 8.4 JoggingProvider GPS & Health Details

- GPS: `Geolocator.getPositionStream(distanceFilter: 3m)`
- Noise filter: buang jumps > 30m
- Real-time HR & calories poll setiap 30 detik
- On stop: fetch real steps via `fetchStepsInInterval()`
- Heart rate averaging pakai integer division (`~/`) -- truncates precision
- **GPS stream tanpa `onError`** -- error = tracking mati tanpa notifikasi

---

## 9. UI Screens

### 9.1 MainScreen (di main.dart, 116 baris)

- 5 tabs: Beranda, Tugas, Jogging, Progress, Profil
- Bottom nav dengan custom styling (20px top border radius, BoxShadow)
- FAB gradient accent circle → push ke AiChatScreen
- **Masalah:** Semua 5 screen di-instantiate setiap build. Tidak pakai `IndexedStack`.

### 9.2 DashboardScreen (1.159 baris)

**Sections:**
1. Greeting -- time-of-day + nama dari profile
2. Energy Level Card -- gradient container, percentage, emoji, status message, CircularProgressIndicator
3. Daily Summary -- 2x2 grid (Steps, Calories, HR, Sleep), tappable → bottom sheet dengan bar chart manual + 7-day history
4. Quick Actions -- "Mulai Jogging" → switch ke tab 2
5. Health Connect Warning -- yellow banner kalau belum sync
6. Sticky Notes -- horizontal ListView, pastel cards (140x140px), "scotch tape" decoration
7. Today's Schedule -- recurring tasks dengan times
8. AI Recommendations -- static card dari energy.recommendations

**Masalah:**
- `_iconCache` dan `_formatSteps` adalah dead code (never called)
- Hand-rolled bar chart (~200 baris) di `_showMetricDetail` -- seharusnya pakai fl_chart
- Pastel color list terdefinisi 3 kali dalam file yang sama
- Dark mode hardcoded `Color(0xFF1E1E1E)`

### 9.3 TasksScreen (1.325 baris)

**Fitur:**
- Category tabs (Semua, Mengajar, Les, Pribadi, Olahraga)
- Task list dengan checkbox toggle
- Swipe-to-dismiss dengan undo (SnackBar)
- Create: manual (`AddTaskForm`) atau AI-powered (WhatsApp paste → NVIDIA NIM parse)
- Recurring tasks dengan time picker
- **Tidak ada edit functionality** untuk existing tasks

**AddTaskForm (inline, 400+ baris):**
- Fields: title, description, category, time of day, energy (1-5 bolts), start/end time, recurring
- Validasi: hanya cek title non-empty
- Tidak ada FormKey atau formal validation

**WhatsApp Paste Feature:**
- `NvidiaService.parseTasks()` → tampilkan results → batch save
- Error handling ada (red container + icon)
- API key prompt jika belum di-set

**Masalah:**
- `ListView.builder` + `shrinkWrap: true` + `NeverScrollableScrollPhysics` inside `SingleChildScrollView` -- defeats lazy loading
- Bottom padding 80px hardcoded untuk FAB
- `AddTaskForm` harusnya di `lib/widgets/`

### 9.4 JoggingScreen (560 baris)

**Dua views:**
1. **Setup** -- Circular gradient button (180x180) + "Workout Terakhir" (max 3 items)
2. **Active Session** -- GPS badge, timer (64px), 2x2 metrics (Distance, Pace, Calories, HR), controls

**Controls:**
- Discard (close icon) → confirmation dialog
- Pause/Resume (FAB.large) -- toggles pink↔teal
- Stop & Save (red) -- validasi minimum 50m

**Animasi:** `_HeartPulseIcon` -- scale animation 1.0→1.3, 800ms easeInOut repeat

**Masalah:**
- Tidak ada map visualization untuk GPS route
- Tidak ada AppBar -- bare Scaffold
- Tidak ada error state jika GPS gagal
- `_formatDate` dengan Indonesian month names -- duplikasi di 4 file

### 9.5 ProgressScreen (555 baris)

**Sections:**
1. Header -- title + sync status
2. Weekly Summary -- gradient card (Steps, Calories, Workouts, Streak)
3. Achievements -- 3-column (streak, total distance, total sessions)
4. Steps Chart -- fl_chart BarChart, 7 hari, green/pink bars berdasarkan goal
5. Detailed Stats -- 2x2 grid (Distance, Pace, Time, Calories)

**Streak calculation:** Gabungkan step goal dates + workout dates, hitung consecutive backwards dari hari ini.

**Masalah:**
- `_formatPace()` no-op -- return input tanpa formatting
- Average pace parsing fragil (split on ":")
- Baca Hive langsung di `build()` -- bypass provider
- `_syncHistoricalFromHealth()` tidak invalidate metricsProvider
- Bar tooltip `Colors.black87` mungkin invisible di dark mode

### 9.6 ProfileScreen (1.201 baris)

**Settings items:**
1. Edit Profile -- name + step goal
2. Notifications -- informational dialog (no toggle)
3. Health Connect -- step-by-step instructions, sync, diagnostics
4. Huawei Watch -- connection dialog (sign-in stub)
5. Dark Mode -- Switch toggle
6. Bahasa -- informational only (no actual switching)
7. Bantuan -- email support
8. Tentang -- app description
9. Beri Rating -- thank you dialog

**Diagnostics viewer:** Monospace colored log entries, delete + dump options.

**Masalah:**
- "Putuskan Koneksi" Huawei tidak fungsional (comment: "no explicit signOut")
- Tidak ada actual profile image upload
- Language switching no-op
- Notification setting no-op (no toggle)
- Version "v1.0.0" hardcoded

### 9.7 AiChatScreen (78 baris) -- PLACEHOLDER

- Static "Asisten AI -- Segera Hadir"
- Tidak ada chat input, message list, atau API calls
- Tidak import `aiChatProvider`
- FAB navigasi ke sini tapi user dapat "coming soon" message

---

## 10. Theme & Styling

### 10.1 Color System (AppColors)

| Color | Hex | Usage |
|---|---|---|
| primary | `#FF8A9B` | Soft pink, main brand |
| primaryLight | `#FFB5C0` | Light variant |
| primaryDark | `#E85D75` | Dark variant |
| accent | `#4ECDC4` | Teal, secondary |
| accentLight | `#7EDDD6` | Light teal |
| background | `#FFF5F7` | Page background |
| surface | `#FFFFFF` | Card surface |
| textPrimary | `#2D2D2D` | Main text |
| textSecondary | `#7A7A7A` | Secondary text |
| divider | `#F0F0F0` | Divider lines |
| error | `#FF6B6B` | Error states |
| success | `#51CF66` | Success states |
| warning | `#FFD43B` | Warning states |

### 10.2 Light Theme

- Material 3 enabled
- AppBar solid pink
- Cards: 16px border radius, elevation 2
- Bottom nav: `BottomNavigationBarType.fixed`
- Text theme: 6 tiers (headlineLarge → bodyMedium)
- FAB: gradient accent

### 10.3 Dark Theme

- Surface: `#1E1E1E`, scaffold: `#121212`
- AppBar matches surface
- Primary becomes `primaryLight` in dark mode
- Bottom nav: grey for unselected
- **Missing:** fabTheme, textTheme, inputDecorationTheme (vs light theme)

### 10.4 Masalah Styling

| Masalah | Frequency |
|---|---|
| Dark mode `Color(0xFF1E1E1E)` hardcoded | 20+ kali across screens |
| `isDark` check via `Theme.of(context).brightness == Brightness.dark` | Setiap build method |
| Border radius inconsistent (12px, 16px, 20px) | Berbagai card |
| Shadow opacity varies (0.04, 0.06, 0.15) | Berbagai card |
| Bottom sheet drag handle (`40x4 Container`) diulang | 10+ kali across screens |
| Dark theme kurang lengkap (missing fabTheme, textTheme) | 1 file |

---

## 11. Build & Config

### 11.1 Android Configuration

| Setting | Value |
|---|---|
| compileSdk | 36 |
| minSdk | 26 |
| targetSdk | `flutter.targetSdkVersion` (dynamic) |
| Java | VERSION_17 |
| Kotlin | JVM_17 |
| Core library desugaring | enabled (2.1.4) |
| HMS Health Kit | `com.huawei.hms:health:9.4.0+300` |

### 11.2 Masalah Build

1. **Release signing crash** -- `keystoreProperties["keyAlias"] as String` akan NullPointerException jika `key.properties` tidak ada. Guard hanya di file existence check, signing config block execute unconditionally.

2. **HMS Health Kit tanpa conditional** -- ditambahkan unconditionally ke APK, menambah size meskipun HMS tidak tersedia di device.

3. **Tidak ada ProGuard/R8 rules** -- Huawei Health SDK, Health Connect, dan Dio semua butuh ProGuard keep rules untuk release build. Kalau obfuscation aktif, reflection-based code akan break.

4. **`key.properties` tidak di-gitignore** -- PASSWORD PLAINTEXT (`runwithyou7`) BISA TERCOCOMMIT.

---

## 12. Daftar Masalah Lengkap

### HIGH Severity

| # | Issue | Lokasi | Dampak |
|---|---|---|---|
| H1 | Race condition concurrent `saveMetrics()` -- non-atomic read-then-write | `hive_service.dart:222-249` | Data loss saat multi-source sync |
| H2 | `key.properties` (password keystore plaintext) tidak di-gitignore | `android/key.properties` | Security: keystore password exposed |
| H3 | Release signing crash jika `key.properties` missing | `android/app/build.gradle.kts:36` | Build failure |
| H4 | GPS stream tanpa `onError` -- tracking mati diam-diam | `jogging_provider.dart:167` | User tidak tahu GPS gagal mid-jog |

### MEDIUM Severity

| # | Issue | Lokasi | Dampak |
|---|---|---|---|
| M1 | Silent error swallowing -- semua service catch `(_) {}` | Semua service | Debugging mustahil |
| M2 | HuaweiHealthService dead code -- waste startup + APK size | `main.dart:24`, `huawei_health_service.dart` | Startup lambat, APK besar |
| M3 | NvidiaService Dio() tanpa timeout | `nvidia_service.dart:24` | UI freeze saat API hanging |
| M4 | AI Chat provider tidak terhubung ke backend | `ai_chat_provider.dart`, `ai_chat_screen.dart` | Fitur tidak berfungsi |
| M5 | JoggingProvider race condition saat stopAndSaveSession | `jogging_provider.dart:247-257` | Stale data overwrite |
| M6 | Tab switch rebuild semua screen (tidak IndexedStack) | `main.dart:52-116` | Scroll position hilang,性能 |
| M7 | ThemeNotifier/ProfileNotifier bypass HiveService | `theme_provider.dart:11`, `profile_provider.dart:31` | Fragile coupling |
| M8 | NotificationService timezone edge case | `notification_service.dart:14,49,89` | Notifikasi bisa salah waktu |
| M9 | NvidiaService ID collision (timestamp-based) | `nvidia_service.dart:114` | Task overwrite |
| M10 | Concurrent Hive writes tanpa isolation | `metrics_provider.dart`, `health_connect_provider.dart`, `jogging_provider.dart` | Data loss |

### LOW Severity

| # | Issue | Lokasi | Dampak |
|---|---|---|---|
| L1 | `go_router` dependency unused | `pubspec.yaml` | Waste dependency |
| L2 | `widgets/` directory kosong -- tidak ada widget extraction | `lib/widgets/` | Code duplication |
| L3 | Dark mode styling inconsistent | Semua screen | Visual inconsistency |
| L4 | progress_screen bypass provider, baca Hive langsung | `progress_screen.dart:120,130` | Data bisa stale |
| L5 | `_formatPace()` no-op | `progress_screen.dart:68-70` | Dead code |
| L6 | Dead code: `_iconCache`, `_formatSteps` | `dashboard_screen.dart:14-20, 42-48` | Dead code |
| L7 | Month/day name arrays terduplikasi di 4 file | Dashboard, Tasks, Jogging, Progress | Code duplication |
| L8 | Category color mapping terduplikasi | `tasks_screen.dart:32-45`, `dashboard_screen.dart:360-369` | Code duplication |
| L9 | `tabIndexProvider` custom setter unconventional | `tab_provider.dart:9` | Code smell |
| L10 | `NoteModel`/`WorkoutModel` fromMap tanpa null guard | `note.dart`, `workout.dart` | Runtime error risk |
| L11 | Pastel color list terdefinisi 3x dalam dashboard | `dashboard_screen.dart` | Code duplication |
| L12 | ProfileScreen: Huawei disconnect button no-op | `profile_screen.dart:846-858` | Fake functionality |
| L13 | ProfileScreen: Language toggle no-op | `profile_screen.dart` | Fake functionality |
| L14 | Bottom sheet padding 80px hardcoded | `tasks_screen.dart:876` | Fragile layout |

### INFORMATIONAL

| # | Issue | Catatan |
|---|---|---|
| I1 | No TypeAdapters -- semua model pakai Map serialization | Acceptable untuk scale |
| I2 | README.md masih boilerplate default | Perlu update |
| I3 | No tests除了 single smoke test | Test coverage minim |
| I4 | No localization framework -- semua hardcoded Indonesia | Acceptable untuk single-language app |
| I5 | `._Screenshot` macOS resource fork file | Should be gitignored |
| I6 | `data_layer_analysis.md` di project root | Generated, bukan source |
| I7 | Duplicate comment di `hive_service.dart:42` | Cosmetic |

---

## 13. Rekomendasi

### Prioritas 1: Fix Security & Crash Risks

1. **Gitignore `key.properties`** -- tambah `/android/key.properties` ke `.gitignore`
2. **Fix release signing guard** -- pindah signing config block ke dalam `if (keystorePropertiesFile.exists())`
3. **Tambahkan `onError` ke GPS stream** -- handle GPS failure dengan user notification

### Prioritas 2: Fix Data Integrity

4. **Add mutex/lock ke `saveMetrics()`** -- atau serialize writes via a queue
5. **Tambahkan error logging** di semua `catch (_) {}` blocks
6. **Add timeout ke NvidiaService Dio** -- `connectTimeout: 10s, receiveTimeout: 30s`

### Prioritas 3: Cleanup Dead Code

7. **Remove HuaweiHealthService dari main.dart init** (atau complete Phase 5)
8. **Remove `go_router` dari pubspec.yaml**
9. **Remove dead code** (`_iconCache`, `_formatSteps`, `_formatPace`)

### Prioritas 4: Widget Extraction

10. **Extract ke `lib/widgets/`:**
    - `AddTaskForm` (dari tasks_screen)
    - `BottomSheetContainer` (drag handle + rounded corners)
    - `SummaryCard` (stat card pattern)
    - `CategoryBadge` (category colors/icons)
    - `StickyNoteCard` (dari dashboard)

### Prioritas 5: UI Consistency

11. **Ganti semua hardcoded `Color(0xFF1E1E1E)`** dengan `Theme.of(context).colorScheme.surface`
12. **Standardisasi** border radius, shadow opacity
13. **Tambahkan missing dark theme properties** (fabTheme, textTheme)

### Prioritas 6: Features

14. **Wire AI Chat** -- connect aiChatProvider ke OpenRouter API via dio
15. **Add IndexedStack** di MainScreen untuk preserve scroll position
16. **Add edit task functionality**

---

*Laporan ini dihasilkan oleh 6 sub-agent paralel pada 31 Juli 2026.*
