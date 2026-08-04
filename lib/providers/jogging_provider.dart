import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/workout.dart';
import 'workout_provider.dart';
import 'metrics_provider.dart';
import '../services/health_service.dart';
import '../services/huawei_health_service.dart';

class JoggingSessionState {
  final bool isActive;
  final bool isPaused;
  final int duration; // in seconds
  final double distance; // in km
  final int? calories;
  final String currentPace; // 'MM:SS' / 'km/h'
  final int? currentHeartRate;
  final List<Position> pathPoints;

  JoggingSessionState({
    this.isActive = false,
    this.isPaused = false,
    this.duration = 0,
    this.distance = 0.0,
    this.calories,
    this.currentPace = '00:00',
    this.currentHeartRate,
    this.pathPoints = const [],
  });

  JoggingSessionState copyWith({
    bool? isActive,
    bool? isPaused,
    int? duration,
    double? distance,
    int? calories,
    String? currentPace,
    int? currentHeartRate,
    bool clearHeartRate = false,
    bool clearCalories = false,
    List<Position>? pathPoints,
  }) {
    return JoggingSessionState(
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      duration: duration ?? this.duration,
      distance: distance ?? this.distance,
      calories: clearCalories ? null : (calories ?? this.calories),
      currentPace: currentPace ?? this.currentPace,
      currentHeartRate: clearHeartRate ? null : (currentHeartRate ?? this.currentHeartRate),
      pathPoints: pathPoints ?? this.pathPoints,
    );
  }
}

class JoggingNotifier extends Notifier<JoggingSessionState> {
  Timer? _timer;
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _sessionStartTime;
  int _syncTickCount = 0;

  @override
  JoggingSessionState build() {
    ref.onDispose(() {
      _stopTimer();
      _stopGps();
    });
    return JoggingSessionState();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.isActive && !state.isPaused) {
        final newDuration = state.duration + 1;
        
        double newDistance = state.distance;
        String newPace = state.currentPace;

        final minutes = newDuration / 60;
        if (newDistance > 0) {
          final paceVal = minutes / newDistance;
          final paceMin = paceVal.floor();
          final paceSec = ((paceVal - paceMin) * 60).round();
          newPace = '${paceMin.toString().padLeft(2, '0')}:${paceSec.toString().padLeft(2, '0')}';
        }

        state = state.copyWith(
          duration: newDuration,
          distance: newDistance,
          currentPace: newPace,
        );

        // Periodically sync real heart rate & calories (every 30 seconds).
        // Huawei Band dibaca langsung via HMS Health Kit (readLatestData) saat
        // terhubung; Health Connect hanya fallback. 30s keseimbangan yang baik
        // antara responsivitas UI dan konsumsi baterai.
        _syncTickCount++;
        if (_syncTickCount >= 30) {
          _syncTickCount = 0;
          _syncRealTimeHealthData();
        }
      }
    });
  }

  Future<void> _syncRealTimeHealthData() async {
    if (!state.isActive || _sessionStartTime == null) return;

    try {
      final now = DateTime.now();
      
      // 1. Latest Heart Rate — Huawei Band primer bila terhubung, fallback ke
      //    Health Connect (Google). Band tidak menulis ke Health Connect secara
      //    native, jadi jalur Huawei penting untuk HR real-time saat jogging.
      final huaweiHR = HuaweiHealthService.isSignedIn
          ? await HuaweiHealthService.fetchLatestHeartRate()
          : null;
      final latestHR = huaweiHR ?? await HealthService.fetchLatestHeartRate();
      
      // 2. Fetch active calories burned during this session
      final activeCalories = await HealthService.fetchCaloriesInInterval(_sessionStartTime!, now);

      if (state.isActive) {
        state = state.copyWith(
          currentHeartRate: latestHR,
          calories: activeCalories,
          clearHeartRate: latestHR == null,
          clearCalories: activeCalories == null,
        );
      }
    } catch (_) {}
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<bool> _checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<void> _startGps() async {
    final hasPermission = await _checkLocationPermissions();
    if (!hasPermission) {
      return;
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Update location every 3 meters
      ),
    ).listen((Position position) {
      if (state.isActive && !state.isPaused) {
        final updatedPoints = List<Position>.from(state.pathPoints)..add(position);
        double addedDistance = 0.0;

        if (state.pathPoints.isNotEmpty) {
          final lastPos = state.pathPoints.last;
          final distInMeters = Geolocator.distanceBetween(
            lastPos.latitude,
            lastPos.longitude,
            position.latitude,
            position.longitude,
          );
          // Ignore location jumps/noise (e.g. more than 30 m/s is unrealistic for running)
          if (distInMeters < 30) {
            addedDistance = distInMeters / 1000.0; // convert to km
          }
        }

        state = state.copyWith(
          distance: state.distance + addedDistance,
          pathPoints: updatedPoints,
        );
      }
    });
  }

  void _stopGps() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> startSession() async {
    _sessionStartTime = DateTime.now();
    _syncTickCount = 0;
    state = JoggingSessionState(
      isActive: true,
      isPaused: false,
    );

    _startTimer();
    await _startGps();
  }

  void togglePause() {
    state = state.copyWith(isPaused: !state.isPaused);
  }

  Future<void> stopAndSaveSession() async {
    _stopTimer();
    _stopGps();

    if (state.distance > 0.05) {
      // Fetch actual steps during the workout interval from Health Connect
      final realSteps = _sessionStartTime != null 
          ? await HealthService.fetchStepsInInterval(_sessionStartTime!, DateTime.now())
          : null;
      // Fallback to GPS distance-based estimate if no steps were recorded in Health Connect
      final stepsEarned = realSteps ?? (state.distance * 1250).toInt();

      // 1. Save Workout to History
      final finalPace = state.currentPace == '00:00' ? '00:00' : state.currentPace;
      final workoutCalories = state.calories ?? (state.distance * 65).toInt();
      final workoutHR = state.currentHeartRate ?? 0;

      final workout = WorkoutModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        distance: state.distance,
        duration: state.duration,
        calories: workoutCalories,
        averagePace: finalPace,
        averageHeartRate: workoutHR,
        date: DateTime.now(),
      );

      // Add to workout provider
      await ref.read(workoutProvider.notifier).addWorkout(workout);

      // 2. Sync to Daily Metrics (add steps & calories to today)
      final dailyMetrics = ref.read(metricsProvider);
      
      final currentAvgHR = dailyMetrics.averageHeartRate ?? 0;
      await ref.read(metricsProvider.notifier).updateMetrics(
        steps: (dailyMetrics.steps ?? 0) + stepsEarned,
        calories: (dailyMetrics.calories ?? 0) + workoutCalories,
        averageHeartRate: workoutHR == 0 
            ? (currentAvgHR > 0 ? currentAvgHR : null)
            : (currentAvgHR == 0 
                ? workoutHR 
                : ((currentAvgHR + workoutHR) ~/ 2)),
      );
    }

    state = JoggingSessionState(); // Reset state
    _sessionStartTime = null;
  }

  void discardSession() {
    _stopTimer();
    _stopGps();
    state = JoggingSessionState(); // Reset state
    _sessionStartTime = null;
  }
}

final joggingProvider = NotifierProvider<JoggingNotifier, JoggingSessionState>(JoggingNotifier.new);
