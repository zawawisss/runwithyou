import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/theme.dart';
import '../providers/workout_provider.dart';
import '../providers/profile_provider.dart';
import '../services/hive_service.dart';
import '../services/health_service.dart';
import '../widgets/health_coming_soon_card.dart';
import '../models/daily_metrics.dart';
import '../models/workout.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncHistoricalFromHealth();
    });
  }

  Future<void> _syncHistoricalFromHealth() async {
    if (_isSyncing) return;
    if (mounted) setState(() => _isSyncing = true);

    try {
      final now = DateTime.now();
      // Always re-fetch all 7 days from Health Connect — don't trust Hive cache
      for (int i = 0; i <= 6; i++) {
        final date = now.subtract(Duration(days: i));
        final metrics = await HealthService.fetchMetricsForDate(date);
        if (metrics != null) {
          await HiveService.saveMetrics(metrics);
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isSyncing = false);
  }

  String _formatToday() {
    final now = DateTime.now();
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _formatNumber(num number) {
    if (number is double) {
      return number.toStringAsFixed(1);
    }
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  String _formatPace(String paceStr) {
    return paceStr;
  }

  int _calculateStreak(List<DailyMetricsModel> allMetrics, List<WorkoutModel> workouts, int stepGoal) {
    final today = DateTime.now();
    int streak = 0;

    final activeDates = <String>{};

    for (final m in allMetrics) {
      if (m.steps != null && m.steps! >= stepGoal) {
        activeDates.add(_formatDateKey(m.date));
      }
    }
    for (final w in workouts) {
      activeDates.add(_formatDateKey(w.date));
    }

    DateTime checkDate = today;
    while (true) {
      final key = _formatDateKey(checkDate);
      if (activeDates.contains(key)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        if (checkDate == today) {
          checkDate = checkDate.subtract(const Duration(days: 1));
          final yesterdayKey = _formatDateKey(checkDate);
          if (activeDates.contains(yesterdayKey)) {
            continue;
          }
        }
        break;
      }
    }

    return streak;
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getDayNameIndonesian(DateTime date) {
    final days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    return days[date.weekday % 7];
  }

  @override
  Widget build(BuildContext context) {
    final workouts = ref.watch(workoutProvider);
    final allMetrics = HiveService.getAllMetrics();
    final profile = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final now = DateTime.now();
    final last7Days = List.generate(7, (index) {
      return now.subtract(Duration(days: 6 - index));
    });

    final weeklyMetrics = last7Days.map((day) {
      return HiveService.getMetricsForDate(day);
    }).toList();

    final weeklyTotalSteps = weeklyMetrics.fold<int>(0, (sum, m) => sum + (m.steps ?? 0));
    final weeklyTotalCalories = weeklyMetrics.fold<int>(0, (sum, m) => sum + (m.calories ?? 0));

    final weeklyWorkouts = workouts.where((w) {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      return w.date.isAfter(sevenDaysAgo);
    }).length;

    final streak = _calculateStreak(allMetrics, workouts, profile.stepGoal);

    final totalDistance = workouts.fold<double>(0.0, (sum, w) => sum + w.distance);
    final totalWorkoutCalories = workouts.fold<int>(0, (sum, w) => sum + w.calories);
    final totalDurationSeconds = workouts.fold<int>(0, (sum, w) => sum + w.duration);
    final totalHours = totalDurationSeconds / 3600.0;

    String averagePace = '00:00';
    if (workouts.isNotEmpty) {
      double totalPaceMinutes = 0.0;
      int validCount = 0;
      for (final w in workouts) {
        final parts = w.averagePace.split(':');
        if (parts.length == 2) {
          final minutes = double.tryParse(parts[0]);
          final seconds = double.tryParse(parts[1]);
          if (minutes != null && seconds != null) {
            totalPaceMinutes += minutes + (seconds / 60.0);
            validCount++;
          }
        }
      }
      if (validCount > 0) {
        final avgPaceVal = totalPaceMinutes / validCount;
        final avgMin = avgPaceVal.floor();
        final avgSec = ((avgPaceVal - avgMin) * 60).round();
        averagePace = '${avgMin.toString().padLeft(2, '0')}:${avgSec.toString().padLeft(2, '0')}';
      }
    }

    final maxSteps = weeklyMetrics.isEmpty
        ? 10000.0
        : weeklyMetrics.map((m) => m.steps ?? 0).fold<int>(0, (prev, element) => element > prev ? element : prev).toDouble();
    final double chartMaxY = (maxSteps > profile.stepGoal ? maxSteps * 1.15 : (profile.stepGoal + 2000).toDouble()).toDouble();

    final List<BarChartGroupData> barGroups = List.generate(7, (index) {
      final metrics = weeklyMetrics[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: (metrics.steps ?? 0).toDouble(),
            color: (metrics.steps ?? 0) >= profile.stepGoal ? AppColors.accent : AppColors.primary,
            width: 14,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: chartMaxY,
              color: isDark ? Colors.grey[900] : Colors.grey[100],
            ),
          ),
        ],
      );
    });

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _syncHistoricalFromHealth,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Progress & Riwayat',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (_isSyncing) ...[
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Mengambil data dari Health Connect...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ] else
                              Text(
                                'Diperbarui pada ${_formatToday()}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSyncing ? null : _syncHistoricalFromHealth,
                    icon: Icon(
                      Icons.sync,
                      color: _isSyncing ? Colors.grey : AppColors.primary,
                    ),
                    tooltip: 'Sync dari Health Connect',
                  ),
                ],
              ),
              const SizedBox(height: 24),

            // Weekly Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Minggu Ini',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildWeeklyStat('Langkah', _formatNumber(weeklyTotalSteps)),
                      _buildWeeklyStat('Kalori', '${_formatNumber(weeklyTotalCalories)} kcal'),
                      _buildWeeklyStat('Workout', weeklyWorkouts.toString()),
                      _buildWeeklyStat('Streak', '$streak Hari'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Achievement Section
            Text(
              'Pencapaian',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAchievement(
                  icon: Icons.emoji_events,
                  label: '$streak Hari Beruntun',
                  color: AppColors.warning,
                  context: context,
                ),
                const SizedBox(width: 12),
                _buildAchievement(
                  icon: Icons.directions_run,
                  label: '${_formatNumber(totalDistance)} km Total',
                  color: AppColors.accent,
                  context: context,
                ),
                const SizedBox(width: 12),
                _buildAchievement(
                  icon: Icons.star,
                  label: '${workouts.length} Sesi Jogging',
                  color: AppColors.primary,
                  context: context,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Steps Chart Section
            Text(
              'Grafik Langkah (7 Hari Terakhir)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            if (weeklyMetrics.any((m) => m.hasAnyHealthData))
            Container(
              width: double.infinity,
              height: 240,
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: chartMaxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${_formatNumber(rod.toY.toInt())} lgh',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < 7) {
                            final date = last7Days[index];
                            final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
                            return SideTitleWidget(
                              meta: meta,
                              space: 4,
                              child: Text(
                                isToday ? 'Hari' : _getDayNameIndonesian(date),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                  color: isToday ? AppColors.primary : (isDark ? Colors.grey[400] : AppColors.textSecondary),
                                ),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            )
            else
              const HealthComingSoonCard(),
            const SizedBox(height: 24),

            // Detailed Stats Grid
            Text(
              'Statistik Detail',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDetailStat('Total Jarak', '${_formatNumber(totalDistance)} km', context),
                const SizedBox(width: 12),
                _buildDetailStat('Rata-rata Pace', '${_formatPace(averagePace)} /km', context),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDetailStat('Total Waktu', '${_formatNumber(totalHours)} jam', context),
                const SizedBox(width: 12),
                _buildDetailStat('Kalori Terbakar', '${_formatNumber(totalWorkoutCalories)} kcal', context),
              ],
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievement({
    required IconData icon,
    required String label,
    required Color color,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
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
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
