import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/theme.dart';
import '../providers/metrics_provider.dart';
import '../providers/tasks_provider.dart';
import '../providers/energy_provider.dart';
import '../providers/tab_provider.dart';
import '../providers/health_connect_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/notes_provider.dart';
import '../models/note.dart';
import '../services/health_service.dart';

const Map<int, IconData> _iconCache = {
  0xe5d2: Icons.school,
  0xe530: Icons.book,
  0xe54e: Icons.directions_run,
  0xe8d7: Icons.event,
  0xe878: Icons.home,
};

IconData _getIconData(int codePoint) {
  return _iconCache[codePoint] ?? Icons.event;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      return 'Selamat Pagi! ☀️';
    } else if (hour >= 11 && hour < 15) {
      return 'Selamat Siang! 🌤️';
    } else if (hour >= 15 && hour < 18) {
      return 'Selamat Sore! ⛅';
    } else {
      return 'Selamat Malam! 🌙';
    }
  }

  String _formatSteps(int? steps) {
    if (steps == null) return 'No Data';
    return steps.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(metricsProvider);
    final energy = ref.watch(energyProvider);
    final tasks = ref.watch(tasksProvider);
    final profile = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Get recurring tasks with times for today's schedule
    final todaySchedules = tasks.where((t) => t.isRecurring && t.hasTime).toList();
    final notes = ref.watch(notesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(metricsProvider);
        ref.invalidate(energyProvider);
        ref.invalidate(tasksProvider);
        ref.invalidate(notesProvider);
        await ref.read(healthConnectProvider.notifier).syncToday();
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            '${_getGreeting().replaceAll("!", "")}, ${profile.name}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hari yang produktif menunggumu',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[400] : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Energy Level Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Energy Level Hari Ini',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${energy.percentage}%',
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            energy.statusEmoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        energy.statusMessage,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: energy.percentage / 100,
                          strokeWidth: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const Icon(
                        Icons.bolt,
                        color: Colors.white,
                        size: 32,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Daily Summary
          Text(
            'Ringkasan Hari Ini',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryCard(
                icon: Icons.directions_walk,
                label: 'Langkah',
                value: '${metrics.steps ?? 0}',
                color: AppColors.accent,
                context: context,
                onTap: () => _showMetricDetail(context, 'steps', 'Langkah', Icons.directions_walk, AppColors.accent, (v) => '${v.toInt()} langkah'),
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                icon: Icons.local_fire_department,
                label: 'Kalori',
                value: '${metrics.calories ?? 0} kcal',
                color: AppColors.warning,
                context: context,
                onTap: () => _showMetricDetail(context, 'calories', 'Kalori', Icons.local_fire_department, AppColors.warning, (v) => '${v.toInt()} kcal'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildSummaryCard(
                icon: Icons.favorite,
                label: 'Heart Rate',
                value: '${metrics.averageHeartRate ?? 0} bpm',
                color: AppColors.primary,
                context: context,
                onTap: () => _showMetricDetail(context, 'heartRate', 'Heart Rate', Icons.favorite, AppColors.primary, (v) => '${v.toInt()} bpm'),
              ),
              const SizedBox(width: 12),
              _buildSummaryCard(
                icon: Icons.bedtime,
                label: 'Sleep',
                value: '${(metrics.sleepHours ?? 0).toStringAsFixed(1)} jam',
                color: const Color(0xFF9B59B6),
                context: context,
                onTap: () => _showMetricDetail(context, 'sleep', 'Sleep', Icons.bedtime, const Color(0xFF9B59B6), (v) => '${v.toStringAsFixed(1)} jam'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Aksi Cepat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(tabIndexProvider.notifier).state = 2;
              },
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Text(
                'Mulai Jogging',
                style: TextStyle(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Health Connect Sync Status
          Consumer(
            builder: (context, ref, _) {
              final healthState = ref.watch(healthConnectProvider);
              final isDark = Theme.of(context).brightness == Brightness.dark;
              // Only show warning when not synced
              if (healthState.lastSync != null) {
                return const SizedBox.shrink();
              }
              if (healthState.status == HealthSyncStatus.syncing) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Belum terhubung ke smartwatch. Tarik ke bawah untuk sinkron.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Sticky Notes Section
          _buildStickyNotesSection(context, ref, notes),
          const SizedBox(height: 24),

          // Today's Schedule
          Text(
            'Jadwal Hari Ini',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (todaySchedules.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.grey[800]! : AppColors.divider),
              ),
              child: Center(
                child: Text(
                  'Tidak ada jadwal khusus hari ini. 😊',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ...todaySchedules.map((task) {
              Color categoryColor;
              if (task.category == 'Olahraga') {
                categoryColor = AppColors.accent;
              } else if (task.category == 'Mengajar') {
                categoryColor = AppColors.primary;
              } else if (task.category == 'Les') {
                categoryColor = AppColors.warning;
              } else {
                categoryColor = AppColors.textSecondary;
              }

              // Get icon based on category
              IconData taskIcon;
              if (task.category == 'Mengajar') {
                taskIcon = Icons.school;
              } else if (task.category == 'Les') {
                taskIcon = Icons.book;
              } else if (task.category == 'Olahraga') {
                taskIcon = Icons.directions_run;
              } else {
                taskIcon = Icons.event;
              }

              return _buildScheduleItem(
                time: '${task.startTime} - ${task.endTime}',
                title: task.title,
                icon: taskIcon,
                color: categoryColor,
                context: context,
              );
            }).toList(),
          const SizedBox(height: 24),

          // AI Recommendation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.accent.withOpacity(0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Rekomendasi AI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...energy.recommendations.map((rec) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✨ ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: Text(
                          rec,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required BuildContext context,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isDark ? 0.15 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
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
      ),
    );
  }

  Widget _buildScheduleItem({
    required String time,
    required String title,
    required IconData icon,
    required Color color,
    required BuildContext context,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMetricDetail(
    BuildContext context,
    String metricType,
    String title,
    IconData icon,
    Color color,
    String Function(double) formatValue,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(icon, color: color, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '$title — 7 Hari Terakhir',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FutureBuilder<List<MapEntry<DateTime, double>>>(
                      future: HealthService.fetch7DayHistory(metricType),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final data = snapshot.data ?? [];
                        if (data.isEmpty || data.every((e) => e.value == 0)) {
                          return Center(
                            child: Text(
                              'Tidak ada data $title',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                              ),
                            ),
                          );
                        }

                        final maxVal = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
                        final dayLabels = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

                        return ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          children: [
                            // Bar chart
                            SizedBox(
                              height: 180,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: List.generate(data.length, (i) {
                                  final entry = data[i];
                                  final barHeight = maxVal > 0
                                      ? (entry.value / maxVal) * 140
                                      : 0.0;
                                  final dayLabel = dayLabels[entry.key.weekday % 7];
                                  final isToday = i == data.length - 1;

                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          // Value label
                                          if (entry.value > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Text(
                                                formatValue(entry.value),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark ? Colors.grey[300] : color,
                                                ),
                                              ),
                                            ),
                                          // Bar
                                          Container(
                                            height: barHeight.clamp(2, 140),
                                            decoration: BoxDecoration(
                                              color: isToday
                                                  ? color
                                                  : color.withOpacity(0.35),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          // Day label
                                          Text(
                                            isToday ? 'Hari ini' : dayLabel,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                              color: isToday
                                                  ? color
                                                  : (isDark ? Colors.grey[400] : AppColors.textSecondary),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          // Date
                                          Text(
                                            '${entry.key.day}/${entry.key.month}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: isDark ? Colors.grey[500] : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Summary
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSummaryStat(
                                    'Rata-rata',
                                    formatValue(data.map((e) => e.value).reduce((a, b) => a + b) / data.length),
                                    color,
                                    isDark,
                                  ),
                                  _buildSummaryStat(
                                    'Tertinggi',
                                    formatValue(maxVal),
                                    color,
                                    isDark,
                                  ),
                                  _buildSummaryStat(
                                    'Terendah',
                                    formatValue(data.map((e) => e.value).where((v) => v > 0).fold<double>(double.infinity, (a, b) => a < b ? a : b)),
                                    color,
                                    isDark,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[400] : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStickyNotesSection(BuildContext context, WidgetRef ref, List<NoteModel> notes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    const List<Color> pastelColors = [
      Color(0xFFFFF9C4), // Pastel Yellow
      Color(0xFFE3F2FD), // Pastel Blue
      Color(0xFFE8F5E9), // Pastel Green
      Color(0xFFF3E5F5), // Pastel Purple
      Color(0xFFFFE0B2), // Pastel Orange
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Catatan Tempel 📝',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              onPressed: () => _showAddNoteDialog(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (notes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[500]!.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'Belum ada catatan tempel.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                final bgColor = pastelColors[note.colorIndex % pastelColors.length];
                
                return GestureDetector(
                  onTap: () => _showEditNoteDialog(context, ref, note),
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12, bottom: 4),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // Sticky Card
                        Container(
                          width: 140,
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              note.content,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        // Scotch Tape
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 45,
                            height: 14,
                            color: Colors.white.withOpacity(isDark ? 0.35 : 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showAddNoteDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    int selectedColorIndex = 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Tambah Catatan Tempel',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      maxLength: 80,
                      decoration: InputDecoration(
                        hintText: 'Tulis pengingat singkat di sini...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Pilih Warna:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(5, (index) {
                        const List<Color> pastelColors = [
                          Color(0xFFFFF9C4),
                          Color(0xFFE3F2FD),
                          Color(0xFFE8F5E9),
                          Color(0xFFF3E5F5),
                          Color(0xFFFFE0B2),
                        ];
                        final isSelected = selectedColorIndex == index;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColorIndex = index;
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: pastelColors[index],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black87 : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final content = controller.text.trim();
                          if (content.isNotEmpty) {
                            ref.read(notesProvider.notifier).addNote(content, selectedColorIndex);
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditNoteDialog(BuildContext context, WidgetRef ref, NoteModel note) {
    final controller = TextEditingController(text: note.content);
    int selectedColorIndex = note.colorIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Edit Catatan Tempel',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      maxLength: 80,
                      decoration: InputDecoration(
                        hintText: 'Tulis pengingat singkat...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Pilih Warna:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(5, (index) {
                        const List<Color> pastelColors = [
                          Color(0xFFFFF9C4),
                          Color(0xFFE3F2FD),
                          Color(0xFFE8F5E9),
                          Color(0xFFF3E5F5),
                          Color(0xFFFFE0B2),
                        ];
                        final isSelected = selectedColorIndex == index;
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColorIndex = index;
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: pastelColors[index],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.black87 : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              ref.read(notesProvider.notifier).deleteNote(note.id);
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Hapus'),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Batal'),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final content = controller.text.trim();
                              if (content.isNotEmpty) {
                                ref.read(notesProvider.notifier).editNote(note.id, content, selectedColorIndex);
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Simpan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
