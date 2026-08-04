import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class TasksNotifier extends Notifier<List<TaskModel>> {
  @override
  List<TaskModel> build() {
    return HiveService.getTasks();
  }

  Future<void> addTask(TaskModel task) async {
    state = [...state, task];
    await HiveService.saveTask(task);

    // Schedule notification if task has time
    if (task.hasTime) {
      final parts = task.startTime!.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (task.isRecurring) {
        await NotificationService.scheduleDailyNotification(
          title: '📅 ${task.title}',
          body: '${task.category} dimulai pukul ${task.startTime}',
          hour: hour,
          minute: minute,
        );
      } else {
        await NotificationService.scheduleTaskNotification(
          title: '📋 ${task.title}',
          body: '${task.category} dimulai pukul ${task.startTime}',
          hour: hour,
          minute: minute,
        );
      }
    }
  }

  Future<void> toggleTask(String id) async {
    state = state.map((task) {
      if (task.id == id) {
        final updated = task.copyWith(isCompleted: !task.isCompleted);
        HiveService.saveTask(updated);
        return updated;
      }
      return task;
    }).toList();
  }

  Future<void> deleteTask(String id) async {
    // Cancel notification for this task (using task id hash as notification id)
    final taskIdHash = id.hashCode.remainder(100000);
    await NotificationService.cancel(taskIdHash);

    state = state.where((task) => task.id != id).toList();
    await HiveService.deleteTask(id);
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<TaskModel>>(TasksNotifier.new);
