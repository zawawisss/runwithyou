import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';
import '../models/workout.dart';
import '../models/daily_metrics.dart';
import '../models/note.dart';

class HiveService {
  static const String _tasksBoxName = 'tasks_box';
  static const String _workoutsBoxName = 'workouts_box';
  static const String _metricsBoxName = 'metrics_box';
  static const String _settingsBoxName = 'settings_box';
  static const String _notesBoxName = 'notes_box';

  static Future<void> init([String? testPath]) async {
    if (testPath != null) {
      Hive.init(testPath);
    } else {
      await Hive.initFlutter();
    }
    await Hive.openBox(_tasksBoxName);
    await Hive.openBox(_workoutsBoxName);
    await Hive.openBox(_metricsBoxName);
    await Hive.openBox(_settingsBoxName);
    await Hive.openBox(_notesBoxName);

    final tasksBox = Hive.box(_tasksBoxName);
    final settingsBox = Hive.box(_settingsBoxName);
    final notesBox = Hive.box(_notesBoxName);

    // Seed initial data only if the database is clean and empty
    if (tasksBox.isEmpty && notesBox.isEmpty) {
      final now = DateTime.now();

      // Seed user profile settings
      if (settingsBox.get('profile_name') == null) {
        await settingsBox.put('profile_name', 'Fitri');
      }
      if (settingsBox.get('step_goal') == null) {
        await settingsBox.put('step_goal', 8000);
      }

      // Seed tasks (includes recurring schedule-like tasks) (includes recurring schedule-like tasks)
      final tasks = [
        TaskModel(
          id: 's1',
          title: 'Mengajar di Sekolah',
          description: 'Jam mengajar tetap',
          category: 'Mengajar',
          energyRequired: 4,
          timeOfDay: 'Pagi',
          date: now,
          isCompleted: false,
          startTime: '07:00',
          endTime: '14:00',
          isRecurring: true,
        ),
        TaskModel(
          id: 's2',
          title: 'Les Privat Matematika',
          description: 'Jam les tetap',
          category: 'Les',
          energyRequired: 3,
          timeOfDay: 'Malam',
          date: now,
          isCompleted: false,
          startTime: '18:30',
          endTime: '20:00',
          isRecurring: true,
        ),
        TaskModel(
          id: 't1',
          title: 'Siapkan materi Biologi kelas XI',
          description: 'Bab 3: Sistem Peredaran Darah',
          category: 'Mengajar',
          energyRequired: 3,
          timeOfDay: 'Pagi',
          date: now,
          isCompleted: false,
        ),
        TaskModel(
          id: 't2',
          title: 'Beri feedback tugas kelompok kelas XII',
          description: 'Koreksi laporan praktikum fotosintesis',
          category: 'Mengajar',
          energyRequired: 4,
          timeOfDay: 'Siang',
          date: now,
          isCompleted: false,
        ),
        TaskModel(
          id: 't3',
          title: 'Beli susu cair & roti gandum',
          description: 'Stok sarapan sehat',
          category: 'Pribadi',
          energyRequired: 1,
          timeOfDay: 'Sore',
          date: now,
          isCompleted: true,
        ),
        TaskModel(
          id: 't4',
          title: 'Jogging sore keliling taman',
          description: 'Target 30 menit durasi aktif',
          category: 'Olahraga',
          energyRequired: 2,
          timeOfDay: 'Sore',
          date: now,
          isCompleted: false,
        ),
        TaskModel(
          id: 't5',
          title: 'Koreksi tugas les matematika',
          description: 'Punya PR Aljabar siswa SMP',
          category: 'Les',
          energyRequired: 3,
          timeOfDay: 'Malam',
          date: now,
          isCompleted: false,
        ),
      ];
      for (final t in tasks) {
        await tasksBox.put(t.id, t.toMap());
      }

      // Seed notes
      final notes = [
        NoteModel(
          id: 'n1',
          content: 'Minum air minimal 2 liter hari ini! 💧',
          colorIndex: 0,
          date: now,
        ),
        NoteModel(
          id: 'n2',
          content: 'Jangan lupa bawa jas hujan di motor. 🌧️',
          colorIndex: 1,
          date: now,
        ),
        NoteModel(
          id: 'n3',
          content: 'Siapkan modul les aljabar untuk nanti malam.',
          colorIndex: 3,
          date: now,
        ),
      ];
      for (final n in notes) {
        await notesBox.put(n.id, n.toMap());
      }

      // Workout history is built from real jogging sessions only — no seed data needed

      // Historical metrics are sourced directly from Health Connect — no seed data needed
    }
  }

  static Box _getTasksBox() => Hive.box(_tasksBoxName);
  static Box _getWorkoutsBox() => Hive.box(_workoutsBoxName);
  static Box _getMetricsBox() => Hive.box(_metricsBoxName);
  static Box _getNotesBox() => Hive.box(_notesBoxName);

  // --- TASKS API ---
  static List<TaskModel> getTasks() {
    final box = _getTasksBox();
    final rawList = box.values.toList();
    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return TaskModel.fromMap(map);
    }).toList();
  }

  static Future<void> saveTask(TaskModel task) async {
    final box = _getTasksBox();
    await box.put(task.id, task.toMap());
  }

  static Future<void> deleteTask(String id) async {
    final box = _getTasksBox();
    await box.delete(id);
  }

  // --- WORKOUTS API ---
  static List<WorkoutModel> getWorkouts() {
    final box = _getWorkoutsBox();
    final rawList = box.values.toList();
    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return WorkoutModel.fromMap(map);
    }).toList();
  }

  static Future<void> saveWorkout(WorkoutModel workout) async {
    final box = _getWorkoutsBox();
    await box.put(workout.id, workout.toMap());
  }

  static Future<void> deleteWorkout(String id) async {
    final box = _getWorkoutsBox();
    await box.delete(id);
  }

  // --- DAILY METRICS API ---
  static DailyMetricsModel getMetricsForDate(DateTime date) {
    final box = _getMetricsBox();
    final dateStr = _formatDateKey(date);
    final raw = box.get(dateStr);

    // Guard against unexpected non-Map entries (e.g., stray settings like 'dark')
    if (raw == null || raw is! Map) {
      return DailyMetricsModel(
        sleepHours: 0,
        steps: 0,
        calories: 0,
        averageHeartRate: 0,
        date: date,
      );
    }

    final map = Map<String, dynamic>.from(raw);
    return DailyMetricsModel.fromMap(map);
  }

  static Future<void> saveMetrics(DailyMetricsModel metrics) async {
    final box = _getMetricsBox();
    final dateStr = _formatDateKey(metrics.date);
    final raw = box.get(dateStr);

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final existing = DailyMetricsModel.fromMap(map);

      final merged = DailyMetricsModel(
        date: metrics.date,
        steps: (metrics.steps != null && metrics.steps! > 0)
            ? metrics.steps
            : (existing.steps ?? 0),
        calories: (metrics.calories != null && metrics.calories! > 0)
            ? metrics.calories
            : (existing.calories ?? 0),
        sleepHours: (metrics.sleepHours != null && metrics.sleepHours! > 0)
            ? metrics.sleepHours
            : (existing.sleepHours ?? 0.0),
        averageHeartRate: (metrics.averageHeartRate != null && metrics.averageHeartRate! > 0)
            ? metrics.averageHeartRate
            : (existing.averageHeartRate ?? 0),
      );
      await box.put(dateStr, merged.toMap());
    } else {
      await box.put(dateStr, metrics.toMap());
    }
  }

  static List<DailyMetricsModel> getAllMetrics() {
    final box = _getMetricsBox();
    final rawList = box.values.toList();
    final metricsList = <DailyMetricsModel>[];
    for (final item in rawList) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        metricsList.add(DailyMetricsModel.fromMap(map));
      }
    }
    return metricsList;
  }

  // --- NOTES API ---
  static List<NoteModel> getNotes() {
    final box = _getNotesBox();
    final rawList = box.values.toList();
    return rawList.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return NoteModel.fromMap(map);
    }).toList();
  }

  static Future<void> saveNote(NoteModel note) async {
    final box = _getNotesBox();
    await box.put(note.id, note.toMap());
  }

  static Future<void> deleteNote(String id) async {
    final box = _getNotesBox();
    await box.delete(id);
  }

  // --- NVIDIA NIM API KEY ---
  static Future<void> saveNvidiaApiKey(String key) async {
    final box = Hive.box(_settingsBoxName);
    await box.put('nvidia_api_key', key);
  }

  static String? getNvidiaApiKey() {
    final box = Hive.box(_settingsBoxName);
    return box.get('nvidia_api_key') as String?;
  }

  // --- HUAWEI HEALTH OPT-OUT ---
  // Plugin huawei_health tidak punya API sign-out, jadi flag ini menyatakan
  // bahwa user memilih "Putuskan Koneksi" — app berhenti memakai jalur Huawei
  // sampai user connect ulang secara eksplisit.
  static Future<void> setHuaweiOptOut(bool value) async {
    final box = Hive.box(_settingsBoxName);
    await box.put('huawei_opt_out', value);
  }

  static bool getHuaweiOptOut() {
    final box = Hive.box(_settingsBoxName);
    return box.get('huawei_opt_out') ?? false;
  }

  // --- DIAGNOSTICS LOGS ---
  static Future<void> saveDiagnosticsLog(String log) async {
    final box = Hive.box(_settingsBoxName);
    List<String> logs = List<String>.from(box.get('diagnostics_logs') ?? []);
    logs.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)}: $log');
    if (logs.length > 100) logs = logs.sublist(0, 100); // Keep last 100 entries
    await box.put('diagnostics_logs', logs);
  }

  static List<String> getDiagnosticsLogs() {
    final box = Hive.box(_settingsBoxName);
    return List<String>.from(box.get('diagnostics_logs') ?? []);
  }

  static Future<void> clearDiagnosticsLogs() async {
    final box = Hive.box(_settingsBoxName);
    await box.delete('diagnostics_logs');
  }

  // Helper
  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
