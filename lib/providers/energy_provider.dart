import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'metrics_provider.dart';
import 'tasks_provider.dart';

class EnergyStatus {
  final int percentage;
  final String statusMessage;
  final String statusEmoji;
  final List<String> recommendations;

  EnergyStatus({
    required this.percentage,
    required this.statusMessage,
    required this.statusEmoji,
    required this.recommendations,
  });
}

final energyProvider = Provider<EnergyStatus>((ref) {
  final metrics = ref.watch(metricsProvider);
  final tasks = ref.watch(tasksProvider);

  // 1. Calculate Baseline based on Sleep
  int baseline = 75; // default fallback
  final sleep = metrics.sleepHours ?? 0.0;
  if (sleep >= 7.0 && sleep <= 8.5) {
    baseline = 90;
  } else if (sleep >= 6.0 && sleep < 7.0) {
    baseline = 80;
  } else if (sleep > 8.5 && sleep <= 10) {
    baseline = 85;
  } else if (sleep < 6.0 && sleep > 0) {
    final loss = ((6.0 - sleep) * 10).toInt();
    baseline = (65 - loss).clamp(40, 65);
  } else if (sleep == 0) {
    baseline = 60; // no sleep logged yet
  }

  int energy = baseline;

  // 2. Time Drain (Simulated depletion based on the current hour)
  final now = DateTime.now();
  final currentHour = now.hour;
  final hoursSinceMorning = currentHour - 6; // Active day starts at 06:00
  if (hoursSinceMorning > 0) {
    energy -= (hoursSinceMorning * 1.5).toInt(); // 1.5% drain per hour
  }

  // 3. Task Effects (recurring tasks with times = schedule, others = regular tasks)
  for (final task in tasks) {
    // Check if task is for today
    final isToday = task.date.year == now.year &&
        task.date.month == now.month &&
        task.date.day == now.day;

    // Only count today's tasks (not recurring from other days)
    if (!isToday) continue;

    if (task.hasTime && task.isRecurring) {
      // Recurring tasks with times act like schedules
      if (task.category == 'Olahraga') {
        energy += 12; // Exercise boosts energy
      } else if (task.category == 'Mengajar') {
        energy -= 15; // Teaching drains energy
      } else if (task.category == 'Les') {
        energy -= 8; // Tutoring drains
      } else {
        energy -= 5; // Other activities
      }
    } else {
      // Regular tasks
      if (task.isCompleted) {
        energy += 4; // Completion boost
      } else if (task.energyRequired >= 4) {
        energy -= 6; // Heavy pending task drain
      }
    }
  }

  // Clamp the final energy level between 5% and 100%
  energy = energy.clamp(5, 100);

  // Determine Message and recommendations based on energy level
  String statusMessage = '';
  String statusEmoji = '';
  final List<String> recommendations = [];

  if (energy >= 80) {
    statusMessage = 'Energik & Siap Tempur!';
    statusEmoji = '⚡';
    recommendations.add('Hari yang luar biasa untuk menyelesaikan tugas-tugas berat!');
    if (tasks.any((t) => t.category == 'Olahraga' && !t.isCompleted)) {
      recommendations.add('Jangan lewatkan jogging sore agar kebugaranmu tetap terjaga.');
    }
    recommendations.add('Jaga hidrasi tubuh dengan minum air yang cukup saat mengajar.');
  } else if (energy >= 60) {
    statusMessage = 'Cukup Produktif & Stabil';
    statusEmoji = '😊';
    recommendations.add('Kamu punya energi yang cukup untuk menyelesaikan jadwal les hari ini.');
    recommendations.add('Ambil jeda istirahat 5-10 menit di antara jam mengajar.');
    if (sleep < 7.0) {
      recommendations.add('Tidurmu tadi malam kurang optimal (${sleep.toStringAsFixed(1)} jam). Coba tidur lebih awal nanti malam.');
    }
  } else if (energy >= 40) {
    statusMessage = 'Mulai Lelah, Butuh Jeda';
    statusEmoji = '😴';
    recommendations.add('Prioritaskan tugas-tugas yang mendesak saja.');
    recommendations.add('Minum teh hangat atau camilan sehat untuk mengembalikan fokus.');
    recommendations.add('Kurangi intensitas jogging sore ini menjadi jalan santai.');
  } else {
    statusMessage = 'Sangat Lelah, Istirahat Yuk!';
    statusEmoji = '🛌';
    recommendations.add('Batalkan tugas non-mendesak. Tubuhmu butuh pemulihan.');
    recommendations.add('Hindari mengoreksi tugas sekolah atau les di larut malam.');
    recommendations.add('Tidur berkualitas adalah prioritas utamamu saat ini.');
  }

  final completedTasksCount = tasks.where((t) => t.isCompleted && t.date.year == now.year && t.date.month == now.month && t.date.day == now.day).length;
  final incompleteHeavyTasksCount = tasks.where((t) => !t.isCompleted && t.energyRequired >= 4 && t.date.year == now.year && t.date.month == now.month && t.date.day == now.day).length;

  if (completedTasksCount > 0) {
    recommendations.add('Hebat! Kamu sudah menyelesaikan $completedTasksCount tugas hari ini.');
  }
  if (incompleteHeavyTasksCount > 0) {
    recommendations.add('Ada $incompleteHeavyTasksCount tugas berat yang belum selesai. Kerjakan secara bertahap.');
  }

  if (recommendations.isEmpty) {
    recommendations.add('Jaga kesehatan dan jangan lupa tersenyum hari ini!');
  }

  return EnergyStatus(
    percentage: energy,
    statusMessage: statusMessage,
    statusEmoji: statusEmoji,
    recommendations: recommendations,
  );
});
