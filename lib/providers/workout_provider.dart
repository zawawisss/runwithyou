import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout.dart';
import '../services/hive_service.dart';

class WorkoutNotifier extends Notifier<List<WorkoutModel>> {
  @override
  List<WorkoutModel> build() {
    return HiveService.getWorkouts();
  }

  Future<void> addWorkout(WorkoutModel workout) async {
    state = [workout, ...state]; // Let's keep newest workouts first
    await HiveService.saveWorkout(workout);
  }

  Future<void> deleteWorkout(String id) async {
    state = state.where((w) => w.id != id).toList();
    await HiveService.deleteWorkout(id);
  }
}

final workoutProvider = NotifierProvider<WorkoutNotifier, List<WorkoutModel>>(WorkoutNotifier.new);
