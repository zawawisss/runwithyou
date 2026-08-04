# Data Layer Analysis: RunWithYou

> **NOTA (5 Agustus 2026):** Integrasi Huawei Health Kit (HMS) telah **dihapus** dari kode. Bagian 2.3 (`HuaweiHealthService`) dan referensi HMS lain di dokumen ini bersifat historis dan tidak berlaku lagi. Data kesehatan hanya dari Google Health Connect (data Huawei Band masuk lewat bridge "Health Sync").

## 1. Models

### 1.1 TaskModel (`lib/models/task.dart`)

**Purpose:** Represents a single task or scheduled activity. Used across the entire task management UI (CRUD, recurring schedules, energy-level calculations).

**Key fields:**
- `id` (String) — unique identifier, set at creation time
- `title` (String) — task name
- `description` (String, defaults to `''`) — optional detail
- `isCompleted` (bool, defaults to `false`) — completion state
- `date` (DateTime) — task date (for recurring tasks, this is the anchor date; the task shows every day via `isRecurring`)
- `category` (String) — one of `Mengajar`, `Les`, `Pribadi`, `Olahraga`
- `energyRequired` (int, 1-5) — energy drain when the task is active
- `timeOfDay` (String) — `Pagi`, `Siang`, `Sore`, `Malam`
- `startTime` / `endTime` (String?, format `HH:mm`) — optional time range
- `isRecurring` (bool) — if true, the task repeats daily

**Key functions:**
- `hasTime` getter — returns `startTime != null && endTime != null`
- `copyWith({..., clearStartTime, clearEndTime})` — supports explicit nulling of time fields via boolean flags, since nullable fields use `??` semantics
- `toMap()` — serializes booleans as `int` (1/0), date as ISO 8601 string
- `fromMap()` — deserializes, handling both `int` and `bool` for `isCompleted`/`isRecurring` compatibility

**Data flow:** Created in task screens and seed data, stored via `HiveService.saveTask()`, read into providers, displayed in task list views. Recurring tasks are filtered or duplicated in providers to show on appropriate dates. The `energyRequired` field feeds into `energyProvider`'s energy drain calculation.

**Design patterns:** Immutable class with `copyWith`. Manual `toMap()`/`fromMap()` serialization (no Hive TypeAdapters). Boolean-as-int storage for Hive compatibility. Upward-compatible deserialization (`isCompleted == 1 || isCompleted == true`).

**Potential issues:**
- No validation that `energyRequired` stays within 1-5 range
- `timeOfDay` is a raw string with no enum — typo risks
- `id` is generated client-side (`DateTime.now().millisecondsSinceEpoch.toString()`) — collision risk if tasks are created faster than 1ms apart
- Recurring tasks duplicated per-date in providers rather than using a date-filtered view — possible duplication

---

### 1.2 WorkoutModel (`lib/models/workout.dart`)

**Purpose:** Represents a completed jogging session. Created when the user stops a jogging session, stored in the workout history.

**Key fields:**
- `id` (String) — epoch milliseconds as string
- `distance` (double) — in kilometers
- `duration` (int) — in seconds
- `calories` (int) — total burned
- `averagePace` (String) — formatted as `MM:SS` or `km/h`
- `averageHeartRate` (int) — in bpm
- `date` (DateTime) — session date

**Key functions:**
- `copyWith({...})` — standard immutable update pattern
- `toMap()` / `fromMap()` — all fields serialized directly

**Data flow:** Created by `joggingProvider.stopAndSaveSession()`, stored via `HiveService.saveWorkout()`, read for progress charts and workout history. The `distance` field and `averagePace` are used in the progress screen's weekly charts.

**Potential issues:**
- `averagePace` has no type safety — stored as a string (`MM:SS` or `km/h`), which is ambiguous for computation. The progress screen must parse this string to chart pace.
- No `workoutType` field — if the app ever supports other workout types (cycling, walking), this model doesn't distinguish them.
- `id` collision risk same as TaskModel (epoch ms based).

---

### 1.3 DailyMetricsModel (`lib/models/daily_metrics.dart`)

**Purpose:** Health metrics snapshot for a single day. All fields are nullable — a day may have partial data or none.

**Key fields:**
- `sleepHours` (double?) — hours of sleep
- `steps` (int?) — step count
- `calories` (int?) — calories burned
- `averageHeartRate` (int?) — average HR in bpm
- `date` (DateTime) �� metric date (non-nullable)

**Key functions:**
- `copyWith({...})` — standard pattern
- `toMap()` — null values are serialized as `null`, date as ISO 8601
- `fromMap()` — handles nullable int fields via `as int?` cast; `sleepHours` cast via `(num).toDouble()`

**Data flow:** The central health data model. Populated by:
1. `HealthService.fetchTodayMetrics()` — primary path via Google Health Connect
2. `HuaweiHealthService.fetchTodayMetrics()` — secondary path (stub)
3. Store/merge: `HiveService.saveMetrics()` merges new data over existing (keeps non-null on null/zero incoming)
4. Read: `metricsProvider` reads via `HiveService.getMetricsForDate()`
5. Consumption: `energyProvider` uses `sleepHours` for energy baseline and `steps` for activity bonus; progress screen charts all fields

**Potential issues:**
- No `bloodOxygen`, `bloodPressure`, `bodyTemperature` fields — these exist in Health Connect's `dumpAvailableData()` but are not captured
- Metrics are stored keyed by date string (`YYYY-MM-DD`) in a single box �� all metrics types in one box means you can't query metrics-by-type independently
- `averageHeartRate` is computed as arithmetic mean across all raw HR points — this can be misleading if the watch records HR infrequently (e.g., only during exercise)

---

### 1.4 NoteModel (`lib/models/note.dart`)

**Purpose:** A simple sticky-note model for the notes feature. Minimal fields.

**Key fields:**
- `id` (String) — unique identifier
- `content` (String) — the note text
- `colorIndex` (int) — 0-4, maps to pastel colors in UI
- `date` (DateTime) — creation/modification date

**Key functions:**
- `copyWith({...})` — standard pattern, no special null-clear logic
- `toMap()` / `fromMap()` — straightforward serialization

**Data flow:** CRUD in notes screen, stored in `notes_box`. No derived computations consume notes.

**Potential issues:**
- No `title` field — notes are content-only (this may be intentional for quick sticky notes)
- No `updatedAt` timestamp — only `date` is stored, but it's unclear if this represents creation or last-updated time
- `colorIndex` is validated client-side only (likely validated in UI boundary)

---

## 2. Services

### 2.1 HiveService (`lib/services/hive_service.dart`)

**Purpose:** Single point of access for all local database operations. All methods are static. Five Hive boxes: `tasks_box`, `workouts_box`, `metrics_box`, `settings_box`, `notes_box`.

**Key functions:**
- `init([String? testPath])` �� initializes Hive, opens all 5 boxes, seeds sample data on first launch. The `testPath` parameter allows using a temp directory in tests. Seed logic: if both `tasksBox.isEmpty && notesBox.isEmpty`, creates 7 sample tasks (including 2 recurring schedule tasks), 3 sample notes, and profile defaults (`profile_name: 'Fitri'`, `step_goal: 8000`). Historical metrics and workouts are NOT seeded (real sessions only).
- `getTasks()` / `saveTask()` / `deleteTask()` — CRUD for tasks. Values are stored as `Map` (via `toMap()`) in a flat key-value Hive box keyed by task `id`.
- `getWorkouts()` / `saveWorkout()` / `deleteWorkout()` — CRUD for workouts. Same flat-box pattern.
- `getMetricsForDate()` / `saveMetrics()` / `getAllMetrics()` — daily health metrics. Keyed by `YYYY-MM-DD` string format. `saveMetrics()` merges incoming data over existing data, preserving non-null values when incoming is null or zero. `getMetricsForDate()` returns a model with zero defaults when no data exists.
- `getNotes()` / `saveNote()` / `deleteNote()` — CRUD for notes.
- `saveNvidiaApiKey()` / `getNvidiaApiKey()` — persistent storage for NVIDIA NIM API key in `settings_box`.
- `saveDiagnosticsLog()` / `getDiagnosticsLogs()` / `clearDiagnosticsLogs()` — timestamped log queue capped at 100 entries, stored in `settings_box`.

**Design patterns:**
- Static methods everywhere — no dependency injection. Services are essentially global singletons with static state.
- Manual serialization (no Hive TypeAdapters). Booleans stored as `int` 0/1.
- Merge-on-write semantics for metrics: `saveMetrics()` reads existing data, merges non-null incoming values over it, writes back.
- Seed data pattern: guarded by `isEmpty` check on both tasks and notes boxes (not on settings or metrics).

**Potential issues:**
- **Static global state** — no DI makes testing harder; all providers and screens are coupled to concrete static methods
- **Cast risk** — `box.values.toList()` returns `List<dynamic>`; the `Map<String, dynamic>.from(item as Map)` cast in every getter will throw if any value in the box is not a `Map` (e.g., a stray string). `getMetricsForDate()` guards against this with `is! Map` check, but `getTasks()`, `getWorkouts()`, and `getNotes()` do not
- **Metrics box name mismatch** — seed condition checks `tasksBox.isEmpty && notesBox.isEmpty`, but if only one is empty, seeding is skipped entirely. If the tasks box is non-empty but notes are empty (or vice versa), no data is seeded, potentially leaving partial state
- **No box-specific error handling** — if a box hasn't been opened, `Hive.box(boxName)` throws. The static getters (`_getTasksBox()`, etc.) don't guard against this
- **`getAllMetrics()`** iterates ALL values in the metrics box, including non-date-keyed entries (e.g., stray config values). The `is Map` guard helps but non-metric data would still be parsed (and silently produce a model with null fields except date)
- **Metrics merge clobbers zeros** — if the user has `steps: 0` from a sedentary day, and the next sync returns `null` steps, the existing `0` is kept. But if the user wakes up and syncs before walking, the `0` from the first sync is overwritten by the second sync's real count (this is the intended behavior). The reverse case: if the first sync of the day returns real steps, and a subsequent partial sync (e.g., while the watch reconnects) returns null, the real value is preserved. This is correct, but the comment doesn't explain the rationale.
- **No indices** — all queries are full-box scans. `getTasks()` returns every task without filtering. Date filtering happens in providers (Riverpod notifiers), not in the service layer.

---

### 2.2 HealthService (`lib/services/health_service.dart`)

**Purpose:** Wraps the `health` package for Google Health Connect (read-only). The primary health data source.

**Key functions:**
- `init()` — calls `_health.configure()`, catches errors silently
- `requestPermissions()` — requests READ access for all `_allTypes` (steps, HR, sleep varieties, calories)
- `checkPermissions()` — lightweight check, used for UI sync badge
- `fetchLatestHeartRate()` — last 10 minutes, sorted by `dateTo` descending
- `fetchStepsInInterval()` — uses `getTotalStepsInInterval`
- `fetchCaloriesInInterval()` — sums `ACTIVE_ENERGY_BURNED` points
- `fetchTodayMetrics()` — delegates to `fetchMetricsForDate(DateTime.now())`
- `fetchMetricsForDate()` — the core sync function: fetches steps, calories (with 3-type fallback chain: active → total → basal), sleep (with 5-type fallback chain: session → asleep → deep → light → REM), and HR (arithmetic mean of all points). All operations are independently try-caught with diagnostics logging.
- `fetch7DayHistory(String metricType)` — returns `List<MapEntry<DateTime, double>>` for steps/calories/sleep/heartRate over the past 7 days. Repeats the same fetch logic per day. Returns zero-filled list on error.
- `dumpAvailableData()` — diagnostic function: queries 20+ Health Data types for the past 7 days and logs point counts. Used from diagnostics screens.

**Design patterns:**
- **Silent catch-all** — every method wraps its body in `try/catch (_)` and returns null/false on failure. No error propagation to callers.
- **Fallback chain for sleep/calories** — multiple Health Data types are tried in priority order because different wearables write to different types.
- **Diagnostics logging** — every data point count and error is logged via `HiveService.saveDiagnosticsLog()` for debugging.
- **No permission gate** — explicitly avoids calling `hasPermissions` before data reads, relying on the native Health Connect API to handle access control. Rationale documented in code comments.

**Potential issues:**
- **No retry logic** — if Health Connect is temporarily unavailable (e.g., app just launched), a single failure returns null metrics. No retry or queue mechanism.
- **Sleep calculation consistency** — two different sleep calculation paths exist: (1) value-based (v13+: value is in minutes, divide by 60), (2) duration-based (compute from `dateFrom`/`dateTo`). The code uses value-based if `val is NumericHealthValue`, otherwise falls back to duration. But a `NumericHealthValue` could exist with value=0 from certain watches, causing the duration-based path to be skipped even when duration data is available.
- **`fetchMetricsForDate()` runs sequentially** ��� steps → calories → sleep → HR. These could be parallelized for faster sync. On slow Health Connect queries this adds up.
- **`fetch7DayHistory()` is O(n*7)** — for each of the 7 days, it repeats the full query sequence. For calories, it tries 3 types. For sleep, 5 types. That's up to 8 queries per day x 7 days = 56 queries. This is very slow on device.
- **No auth state management** — `requestPermissions()` returns `bool` but the result isn't cached or tracked; callers must manage their own permission state.
- **Sleep window logic** — `sleepWindowStart = startOfDay - 4h`, `sleepWindowEnd = startOfDay + 12h`. This captures sleep from 20:00 to 12:00 the next day. However, if someone naps in the afternoon (e.g., 14:00-15:00), that sleep is captured on the second day's sync (since the 12h offset from midnight tomorrow includes it). The first day's sync window (startOfDay - 4h to startOfDay + 12h) would cap at that day's 12:00.

---

### 2.3 HuaweiHealthService (`lib/services/huawei_health_service.dart`)

**Purpose:** Direct HMS Core integration for Huawei Health Kit. An alternative/additional health data source. Currently a stub — fully implemented but never called from UI.

**Key functions:**
- `init()` — creates `DataController`, catches errors
- `signIn()` — requests 13 read+write scopes (steps, HR, sleep, calories, distance, activity, heart health)
- `fetchTodayMetrics()` — reads steps, calories, HR, sleep from Huawei Health Kit. Returns `DailyMetricsModel` with null fields on failure.
- `fetch7DayHistory()` — iterates the last 7 days, reading daily summations per metric type
- Private helpers: `_readTodaySummation()`, `_readDailySummation()` (uses `readDailySummationList` with `YYYYMMDD` integer format), `_readAvgHeartRate()`, `_readSleep()`

**Design patterns:**
- Same pattern as HealthService: static methods, silent catch-all, diagnostics logging
- Same `DailyMetricsModel` return type — designed to be a drop-in replacement
- `isInitialized` and `isSignedIn` guards on all data-reading methods

**Potential issues:**
- **Not wired to UI** — the service is fully implemented but never instantiated or called from any provider or screen. The CLAUDE.md confirms this: "stub only."
- **Unnecessary write scopes** — `signIn()` requests both READ and WRITE scopes, but the service only reads data. WRITE scopes add friction to the Huawei permission dialog.
- **Duplicate code** — the fetching logic (fallback chains, window calculations) duplicates HealthService. If both services become active, the merging logic and duplicate writes to Hive need careful design.
- **Sleep calculation differs** — `_readSleep()` computes duration from `point.startTime`/`point.endTime`, while HealthService tries to read `value` first. These produce different results if the watch reports sleep differently, making cross-service metrics inconsistent.
- **HMS dependency** — the `huawei_health` package requires Huawei Mobile Services on the device. On non-Huawei Android phones, `DataController.init()` may fail silently, leaving `_isInitialized = false`.

---

### 2.4 NotificationService (`lib/services/notification_service.dart`)

**Purpose:** Local notification scheduling for task reminders. One-time and daily recurring notifications.

**Key functions:**
- `init()` — initializes timezone database and the notifications plugin with Android settings using `@mipmap/ic_launcher` icon. Guarded by `_initialized` flag (idempotent).
- `requestPermission()` — requests Android notification permission (Android 13+), returns `true` on non-Android platforms.
- `scheduleTaskNotification()` — schedules a one-time notification `advanceMinutes` before the target time. Parameters: `title`, `body`, `hour`, `minute`, `advanceMinutes` (default 15). Returns notification `id` or `-1` if scheduled time is in the past.
- `scheduleDailyNotification()` — same as above but with `matchDateTimeComponents: DateTimeComponents.time` for daily recurrence. Does NOT return `-1` for past times (the plugin handles next-day scheduling via timezone matching).
- `cancel(int id)` — cancels a specific notification
- `cancelAll()` — cancels all scheduled notifications

**Design patterns:**
- Singleton via static methods and static `_plugin` instance
- `_initialized` guard for idempotent init
- Notification IDs derived from `DateTime.now().millisecondsSinceEpoch.remainder(100000)` — a hack to get a unique-ish int (Hive uses Strings, but `flutter_local_notifications` requires int IDs)

**Potential issues:**
- **ID collision risk** — `millisecondsSinceEpoch.remainder(100000)` produces a 5-digit integer. Two notifications scheduled in the same millisecond would have the same ID. The `remainder` operation also produces negative values (Dart's `%` vs `remainder` semantics) — negative IDs may behave unexpectedly with the platform notification system.
- **`scheduleTaskNotification()` returns -1 silently** — if the time has passed, `-1` is returned but nothing logs or handles this. The caller (presumably `NotificationService` in task provider) may not check the return value.
- **No iOS/macOS support** — all notification details are Android-specific. `AndroidInitializationSettings` is used without iOS settings. The `requestPermission()` method returns `true` for non-Android without setting up iOS permissions.
- **No notification tap handling** — `initialize()` is called without a `onDidReceiveNotificationResponse` callback. Tapping a notification doesn't navigate anywhere.
- **No category/channel management** — only one hardcoded channel (`task_reminders`). No ability to create notification categories or group notifications.

---

### 2.5 NvidiaService (`lib/services/nvidia_service.dart`)

**Purpose:** AI-powered task parsing via NVIDIA NIM API. Takes plain text (WhatsApp-style notes, freeform text) and extracts structured tasks.

**Key classes:**
- `NvidiaService` — static service with one public method:
  - `setApiKey(String key)` — sets the API key (loaded from Hive via `getNvidiaApiKey()`)
  - `hasKey` getter — returns `true` if API key is non-empty
  - `parseTasks(String text)` — sends text to NVIDIA NIM (`meta/llama-3.1-70b-instruct`), receives JSON array, deserializes to `List<ParsedTask>`. Temperature 0.1 for deterministic output. Strips markdown code fences from response. Maps categories to time-of-day heuristics. Validates categories against allowed set.
- `ParsedTask` — lightweight preview model (not persisted). Has `toTask(DateTime date)` that converts to `TaskModel` with a generated epoch-ms `id`.

**Key functions within `parseTasks()`:**
- System prompt instructs the model to output JSON only with `title`, `category`, `energy(1-5)`
- Category → timeOfDay mapping: `Mengajar` → `Pagi`, `Les` → `Malam`, `Olahraga` → `Sore`, default → `Siang`
- Error handling: `DioException` (network/API errors) and `FormatException` (JSON parse failures) are caught and re-thrown with user-facing Indonesian messages

**Potential issues:**
- **Hardcoded model** — `meta/llama-3.1-70b-instruct` is hardcoded. If NVIDIA deprecates or renames this model, parsing breaks.
- **Hardcoded base URL** — no staging/fallback endpoints.
- **Dio instance created per call** — `Dio()` is constructed fresh each call. No shared client, no interceptors, no connection pooling. This is wasteful and prevents adding retry logic or auth headers globally.
- **Category mapping is guesswork** — inferring time-of-day from category is a heuristic that will be wrong for many tasks (e.g., "Les" on a Saturday morning). The prompt should ask the model to output timeOfDay directly.
- **No streaming** ��� the response is fully awaited before parsing. For long text inputs, this adds latency without user feedback.
- **`setApiKey` is a static setter** — coupled to whatever calls it before `parseTasks()`. No validation that the key is valid until the first API call.
- **`DioException` catch** — catches `DioException` specifically, but the `try` block also includes JSON parsing logic that could throw other exception types. Only `FormatException` is separately caught.

---

## 3. Theme (`lib/utils/theme.dart`)

**Purpose:** Central color palette and Material 3 theme definitions for light and dark modes.

**Key classes:**
- `AppColors` — static color constants:
  - Primary: Soft Pink `#FF8A9B` and variants (light `#FFB3C1`, dark `#E57285`)
  - Accent: Teal `#4ECDC4` and light variant `#7EDDD6`
  - Surfaces: background `#FFF8F9`, surface `#FFFFFF`
  - Text: primary `#2D2D2D`, secondary `#757575`
  - Semantic: error/success reuse primary/accent; warning `#FFB74D` (amber)
- `AppTheme` — two static getters:
  - `light` — returns `ThemeData` with Material 3, rounded cards (16px), centered app bar, fixed bottom nav, FAB colored with primary
  - `dark` — returns `ThemeData` with dark surfaces (`#121212` scaffold, `#1E1E1E` cards/surface), light variant colors, proper `Brightness.dark`

**Data flow:** The `themeProvider` reads the stored theme preference from Hive (`'light'` / `'dark'`), maps to `ThemeMode`, and passes to `MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark)`. The `themeMode` field drives which theme is applied.

**Potential issues:**
- **`error` color equals `primaryDark`** — `AppColors.error` is the same hex as `AppColors.primaryDark` (`#E57285`). This means error states (validation, alerts) use the same color as primary hover/pressed states. A distinct error color (traditionally red) would be clearer.
- **`success` color equals `accent`** — same as above: `AppColors.success == AppColors.accent` (`#4ECDC4`). Reusing accent for both interactive elements and success states is ambiguous.
- **No custom font** — the theme uses default Material Design fonts (Roboto on Android). No custom fonts are loaded.
- **No `inputDecorationTheme`** — text fields use default styling; no custom border radius, padding, or color applied globally.
- **No `elevatedButtonTheme`/`outlinedButtonTheme`** — buttons use default M3 styling except the FAB. This means button colors may not match the app's pink/teal scheme without explicit styling on each widget.
- **Dark mode card theme color matches surface** — both `Color(0xFF1E1E1E)`. Cards have `elevation: 2`, so elevation shadow provides visual separation between card and surface, but on some screen/brightness combinations this may look flat.
- **`onPrimary` in dark mode** — set to `AppColors.textPrimary` (`#2D2D2D`, a dark gray). On `primary` in dark mode, which is `AppColors.primaryLight` (`#FFB3C1`, light pink), dark gray text may have low contrast. M3 typically uses white on primary in dark mode.

---

## 4. Cross-Cutting Concerns

### Serialization Strategy
All four models follow the same pattern: immutable classes with `toMap()` / `fromMap()` and `copyWith()`. No Hive TypeAdapters — booleans stored as `int` 0/1 (`TaskModel`). Dates stored as ISO 8601 strings. Null values stored as `null` in the Map, which Hive handles natively. `DailyMetricsModel.fromMap()` uses `as int?` for nullable fields — this is safe because Hive returns `null` for absent keys, and `as int?` handles both `null` and `int` values.

### Error Handling Pattern
Consistent across all services: **silent catch-all**. Every external operation (Health Connect, Huawei Health Kit, Hive, NVIDIA NIM) is wrapped in `try/catch (_)` that returns a safe default (null, false, or an empty list). The only exception is `NvidiaService.parseTasks()` which re-throws with user-facing Indonesian messages. `HealthService` adds diagnostics logging via `HiveService.saveDiagnosticsLog()` for debugging, but the calling UI never sees errors.

### Data Flow Architecture

```
User Input (UI)
    |
    v
Provider (Riverpod Notifier)  ←── EnergyProvider (derived, watches other providers)
    |
    v
HiveService (static methods)  ──→  Hive boxes (local on-device DB)
    |
    ^
HealthService (Google HC)  ──→  Health Connect (Android system service)
HuaweiHealthService (HMS)  ──→  Huawei Health Kit (HMS Core)
NvidiaService (NVIDIA NIM)  ──→  NVIDIA NIM API (external REST API)
```

All providers talk to HiveService. Health services write to Hive via `HiveService.saveMetrics()`. The only external API call is NVIDIA NIM. No caching layer between Hive and providers.

### Dependency Graph
- `hive_flutter` / `hive` — local persistence (all models + services)
- `health` — Google Health Connect (HealthService)
- `huawei_health` — Huawei Health Kit (HuaweiHealthService)
- `flutter_local_notifications` / `timezone` — notifications (NotificationService)
- `dio` — HTTP client for NVIDIA NIM (NvidiaService)
- `flutter_riverpod` — state management (not in these files, but the consumer)
- `fl_chart` — charting (not in these files, used by progress screen)
- `geolocator` — GPS for jogging (not in these files, used by joggingProvider)
- `permission_handler` — runtime permissions (not in these files)
- `go_router` — declared in pubspec but NOT used (manual navigation via `MaterialPageRoute`)

### Code Smells & Improvement Opportunities

1. **Global static state** — Every service is a static class. No dependency injection, no testability, no lifecycle management. This couples all consumers to concrete implementations.
2. **No repository layer** — Providers call HiveService directly. There's no abstraction between data sources (local Hive, remote Health Connect) and business logic. Adding a cache or remote backup requires changing every provider.
3. **Duplicate fetch logic** — `fetchMetricsForDate()` in `HealthService` and `fetch7DayHistory()` both implement the same fallback chains for calories/sleep. The 7-day history re-fetches from Health Connect instead of reading from Hive.
4. **Metrics merge ambiguity** — `saveMetrics()` merges by replacing zeros with non-zero values. But 0 steps from a sedentary day is legitimate data, and the first sync of the day might return 0 before the user walks. The merge can't distinguish "no data yet" from "zero data".
5. **Hardcoded seeds** — Seed data (tasks, notes, profile) is hardcoded in `HiveService.init()`. Any schema change requires updating both the model and the seed data in lockstep.
6. **No data migration** — Hive stores raw Maps. If a model gains or loses a field, old data doesn't migrate. `fromMap()` uses `as String?` for nullable fields, so missing keys return `null` — this works for additive changes but not for removals or renames.
7. **Missing type-safety for categorical fields** — `timeOfDay`, `category`, and `averagePace` are raw strings. No enums, no validation at the model level. A typo in any provider creates silent mismatches.
