import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/theme.dart';
import '../providers/jogging_provider.dart';
import '../providers/workout_provider.dart';
import '../models/workout.dart';

class JoggingScreen extends ConsumerStatefulWidget {
  const JoggingScreen({super.key});

  @override
  ConsumerState<JoggingScreen> createState() => _JoggingScreenState();
}

class _JoggingScreenState extends ConsumerState<JoggingScreen> {

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _showDiscardConfirmDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Batalkan Sesi?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              'Apakah kamu yakin ingin membatalkan sesi jogging ini? Data tidak akan disimpan.',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Lanjutkan Jogging', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(joggingProvider.notifier).discardSession();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400], foregroundColor: Colors.white),
                    child: const Text('Batalkan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionView(JoggingSessionState session) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // GPS status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.gps_fixed,
                  size: 16,
                  color: AppColors.accent,
                ),
                SizedBox(width: 6),
                Text(
                  'GPS Tracking Aktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Timer Display
          Text(
            _formatDuration(session.duration),
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Text(
            'DURASI',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 48),

          // Main Metrics Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActiveMetric(
                label: 'JARAK (KM)',
                value: session.distance.toStringAsFixed(2),
                color: AppColors.accent,
              ),
              _buildActiveMetric(
                label: 'PACE (/KM)',
                value: session.currentPace,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActiveMetric(
                label: 'KALORI (KCAL)',
                value: (session.calories ?? 0).toString(),
                color: AppColors.warning,
              ),
              _buildActiveMetric(
                label: 'HEART RATE (BPM)',
                value: (session.currentHeartRate ?? 0).toString(),
                color: const Color(0xFFE74C3C),
                showPulse: session.currentHeartRate != null && session.currentHeartRate! > 0 && !session.isPaused,
              ),
            ],
          ),
          const SizedBox(height: 64),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Discard Button
              IconButton(
                onPressed: _showDiscardConfirmDialog,
                icon: const Icon(Icons.close, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                  padding: const EdgeInsets.all(16),
                ),
              ),

              // Pause / Resume FAB
              FloatingActionButton.large(
                onPressed: () {
                  ref.read(joggingProvider.notifier).togglePause();
                },
                backgroundColor: session.isPaused ? AppColors.accent : AppColors.primary,
                child: Icon(
                  session.isPaused ? Icons.play_arrow : Icons.pause,
                  size: 40,
                  color: Colors.white,
                ),
              ),

              // Stop & Save Button
              IconButton(
                onPressed: () async {
                  if (session.distance < 0.05) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Jarak jogging terlalu pendek untuk disimpan (minimal 50 meter)')),
                    );
                    return;
                  }
                  
                  await ref.read(joggingProvider.notifier).stopAndSaveSession();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sesi jogging berhasil disimpan! 🏃‍♀️🎉')),
                  );
                },
                icon: const Icon(Icons.stop, size: 28),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red[100],
                  foregroundColor: Colors.red[600],
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMetric({
    required String label,
    required String value,
    required Color color,
    bool showPulse = false,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: color,
              ),
            ),
            if (showPulse) ...[
              const SizedBox(width: 4),
              _HeartPulseIcon(color: color),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildSetupView() {
    final workouts = ref.watch(workoutProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jogging Tracker',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mulai jogging dengan satu ketukan',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Start Button Card
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    ref.read(joggingProvider.notifier).startSession();
                  },
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 25,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          size: 64,
                          color: Colors.white,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Mulai Jogging',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Recent Workouts Section
          Text(
            'Workout Terakhir',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          if (workouts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.grey[800]! : AppColors.divider),
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_run_outlined, size: 48, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada riwayat jogging.',
                    style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: workouts.take(3).length, // Show up to 3 recent workouts
              itemBuilder: (context, index) {
                final workout = workouts[index];
                return _buildWorkoutItem(workout);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildWorkoutItem(WorkoutModel workout) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final durationMin = workout.duration ~/ 60;
    final durationSec = workout.duration % 60;
    final durationStr = '${durationMin.toString().padLeft(2, '0')}:${durationSec.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(workout.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // HR Tag
              Row(
                children: [
                  const Icon(Icons.favorite, size: 12, color: Color(0xFFE74C3C)),
                  const SizedBox(width: 3),
                  Text(
                    '${workout.averageHeartRate} bpm',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildWorkoutStat(Icons.straighten, '${workout.distance.toStringAsFixed(2)} km', AppColors.accent, 'Jarak', context),
              _buildWorkoutStat(Icons.timer, durationStr, AppColors.primary, 'Durasi', context),
              _buildWorkoutStat(Icons.speed, '${workout.averagePace} /km', AppColors.warning, 'Pace', context),
              _buildWorkoutStat(Icons.local_fire_department, '${workout.calories} kcal', const Color(0xFFE74C3C), 'Kalori', context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutStat(IconData icon, String value, Color color, String label, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(joggingProvider);
    return Scaffold(
      body: session.isActive ? _buildActiveSessionView(session) : _buildSetupView(),
    );
  }
}

class _HeartPulseIcon extends StatefulWidget {
  final Color color;

  const _HeartPulseIcon({required this.color});

  @override
  State<_HeartPulseIcon> createState() => _HeartPulseIconState();
}

class _HeartPulseIconState extends State<_HeartPulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Icon(
        Icons.favorite,
        color: widget.color,
        size: 16,
      ),
    );
  }
}
