import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/theme.dart';
import '../models/task.dart';
import '../providers/tasks_provider.dart';
import '../providers/energy_provider.dart';
import '../services/nvidia_service.dart';
import '../services/hive_service.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _selectedCategory = 'Semua';

  String _formatToday() {
    final now = DateTime.now();
    final days = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = days[now.weekday % 7];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Mengajar':
        return AppColors.primary;
      case 'Les':
        return AppColors.warning;
      case 'Pribadi':
        return const Color(0xFF9B59B6); // Purple
      case 'Olahraga':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  void _showPasteTaskBottomSheet(BuildContext context) {
    // Check if API key is set
    if (!NvidiaService.hasKey || HiveService.getNvidiaApiKey() == null) {
      _showApiKeyDialog(context);
      return;
    }
    NvidiaService.setApiKey(HiveService.getNvidiaApiKey()!);
    _showPasteSheet(context);
  }

  void _showPasteSheet(BuildContext context) {
    final controller = TextEditingController();
    bool isLoading = false;
    List<ParsedTask>? parsedTasks;
    String? errorMessage;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
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
                    'Tempel dari WhatsApp',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Salin pesan dari WA, tempel di sini, AI akan mengubahnya jadi tugas.',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // Input field
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Tempel pesan di sini...\n\nContoh:\n"Ibu Fitri, siapkan materi bab pencernaan kelas XI, presentasi Jumat. Juga koreksi PR aljabar dikumpul besok."',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Convert button
                  if (!isLoading && parsedTasks == null)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;
                          setSheetState(() { isLoading = true; errorMessage = null; });
                          try {
                            final result = await NvidiaService.parseTasks(text);
                            setSheetState(() { parsedTasks = result; isLoading = false; });
                          } catch (e) {
                            setSheetState(() { errorMessage = e.toString().replaceFirst('Exception: ', ''); isLoading = false; });
                          }
                        },
                        icon: const Icon(Icons.auto_awesome, size: 20),
                        label: const Text('Konversi ke Tugas', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                  // Loading
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: AppColors.accent),
                            SizedBox(height: 12),
                            Text('Memproses...', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ),

                  // Error
                  if (errorMessage != null && !isLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: const TextStyle(fontSize: 13, color: Colors.red))),
                        ],
                      ),
                    ),

                  // Results
                  if (parsedTasks != null && !isLoading) ...[
                    Expanded(
                      child: ListView.builder(
                        itemCount: parsedTasks!.length,
                        itemBuilder: (context, index) {
                          final task = parsedTasks![index];
                          final color = _getCategoryColor(task.category);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF121212) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.task_alt, color: color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(task.category, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          Row(children: List.generate(5, (i) =>
                                            Icon(Icons.bolt, size: 12, color: i < task.energyRequired ? AppColors.warning : Colors.grey[300]))),
                                          const SizedBox(width: 8),
                                          Text(task.timeOfDay, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : AppColors.textSecondary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          for (final pt in parsedTasks!) {
                            final t = pt.toTask(DateTime.now());
                            ref.read(tasksProvider.notifier).addTask(t);
                          }
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${parsedTasks!.length} tugas berhasil ditambahkan! ✅')),
                          );
                        },
                        icon: const Icon(Icons.save_alt, size: 20),
                        label: Text('Simpan ${parsedTasks!.length} Tugas', style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          setSheetState(() { parsedTasks = null; errorMessage = null; controller.clear(); });
                        },
                        child: const Text('Konversi Lagi', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showApiKeyDialog(BuildContext context) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
              const Row(
                children: [
                  Icon(Icons.vpn_key, color: AppColors.accent, size: 22),
                  SizedBox(width: 8),
                  Text('Atur API Key NVIDIA NIM',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Masukkan API key dari build.nvidia.com untuk mengaktifkan fitur tempel dari WhatsApp.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'nvapi-xxxxxxxxxxxx',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final key = controller.text.trim();
                    if (key.isNotEmpty) {
                      HiveService.saveNvidiaApiKey(key);
                      NvidiaService.setApiKey(key);
                      Navigator.pop(context);
                      _showPasteSheet(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Simpan & Lanjutkan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddTaskBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const AddTaskForm();
      },
    );
  }

  Widget _buildEnergySuggestionCard(List<TaskModel> todayPendingTasks, int currentEnergy) {
    String suggestionTitle = '';
    String suggestionDesc = '';
    TaskModel? recommendedTask;

    if (todayPendingTasks.isEmpty) {
      suggestionTitle = 'Semua Tugas Selesai! 🎉';
      suggestionDesc = 'Semua tugas untuk hari ini sudah kamu selesaikan. Waktunya istirahat atau melakukan jogging santai!';
    } else {
      if (currentEnergy >= 70) {
        // High energy -> recommend high energy tasks (rating >= 3)
        final heavyTasks = todayPendingTasks.where((t) => t.energyRequired >= 3).toList();
        if (heavyTasks.isNotEmpty) {
          heavyTasks.sort((a, b) => b.energyRequired.compareTo(a.energyRequired));
          recommendedTask = heavyTasks.first;
          suggestionTitle = 'Fokus pada Tugas Berat ⚡';
          suggestionDesc = 'Tingkat energimu sedang tinggi ($currentEnergy%). Ini waktu terbaik untuk menyelesaikan tugas yang membutuhkan fokus penuh:';
        }
      } else if (currentEnergy >= 40) {
        // Medium energy -> recommend medium energy tasks (rating 2-3)
        final mediumTasks = todayPendingTasks.where((t) => t.energyRequired == 2 || t.energyRequired == 3).toList();
        if (mediumTasks.isNotEmpty) {
          recommendedTask = mediumTasks.first;
          suggestionTitle = 'Maju Perlahan tapi Pasti 😊';
          suggestionDesc = 'Energimu cukup stabil ($currentEnergy%). Yuk selesaikan tugas tingkat menengah ini:';
        }
      } else {
        // Low energy -> recommend light tasks (rating 1-2)
        final lightTasks = todayPendingTasks.where((t) => t.energyRequired <= 2).toList();
        if (lightTasks.isNotEmpty) {
          recommendedTask = lightTasks.first;
          suggestionTitle = 'Kerjakan yang Ringan Dulu 🛌';
          suggestionDesc = 'Energimu sedang rendah ($currentEnergy%). Sebaiknya kerjakan tugas ringan ini dan jangan dipaksakan:';
        } else {
          // Only heavy tasks left but energy is low
          suggestionTitle = 'Waktunya Istirahat / Jeda Sejenak ☕';
          suggestionDesc = 'Hanya tersisa tugas berat hari ini, padahal energimu rendah ($currentEnergy%). Lebih baik istirahat dulu agar energimu kembali pulih.';
        }
      }

      // Fallback to any task if none matches category criteria
      if (recommendedTask == null && todayPendingTasks.isNotEmpty) {
        recommendedTask = todayPendingTasks.first;
        suggestionTitle = 'Rekomendasi Tugas Berikutnya';
        suggestionDesc = 'Yuk selesaikan tugas berikut ini selagi ada waktu luang:';
      }
    }

    return Container(
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
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: AppColors.accent, size: 22),
              const SizedBox(width: 8),
              Text(
                suggestionTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            suggestionDesc,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (recommendedTask != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getCategoryColor(recommendedTask.category).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: _getCategoryColor(recommendedTask.category),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recommendedTask.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${recommendedTask.timeOfDay} • ${recommendedTask.category}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final energy = ref.watch(energyProvider);
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter today's tasks
    final todayTasks = tasks.where((t) {
      return t.date.year == now.year &&
          t.date.month == now.month &&
          t.date.day == now.day;
    }).toList();

    // Calculate completed statistics
    final completedCount = todayTasks.where((t) => t.isCompleted).length;
    final totalCount = todayTasks.length;
    final progressValue = totalCount > 0 ? completedCount / totalCount : 0.0;

    // Filter tasks based on category tab
    List<TaskModel> filteredTasks = [];
    if (_selectedCategory == 'Semua') {
      filteredTasks = todayTasks;
    } else {
      filteredTasks = todayTasks.where((t) => t.category == _selectedCategory).toList();
    }

    final todayPendingTasks = todayTasks.where((t) => !t.isCompleted).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tasksProvider);
          ref.invalidate(energyProvider);
        },
        color: AppColors.primary,
        child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tugas Hari Ini',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatToday(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _showPasteTaskBottomSheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.paste, color: AppColors.accent, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showAddTaskBottomSheet(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

            // Progress Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accent, AppColors.accentLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Progress Hari Ini',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '$completedCount/$totalCount',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'tugas selesai',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      backgroundColor: Colors.white30,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Energy Recommendation Card
            _buildEnergySuggestionCard(todayPendingTasks, energy.percentage),
            const SizedBox(height: 24),

            // Category Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryTab('Semua'),
                  const SizedBox(width: 8),
                  _buildCategoryTab('Mengajar'),
                  const SizedBox(width: 8),
                  _buildCategoryTab('Les'),
                  const SizedBox(width: 8),
                  _buildCategoryTab('Pribadi'),
                  const SizedBox(width: 8),
                  _buildCategoryTab('Olahraga'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Task List Header
            if (filteredTasks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 64,
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tidak ada tugas di kategori ini.',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = filteredTasks[index];
                  final color = _getCategoryColor(task.category);

                  return Dismissible(
                    key: Key(task.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red[400],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                    ),
                    onDismissed: (direction) {
                      ref.read(tasksProvider.notifier).deleteTask(task.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tugas "${task.title}" berhasil dihapus'),
                          action: SnackBarAction(
                            label: 'Batal',
                            onPressed: () {
                              ref.read(tasksProvider.notifier).addTask(task);
                            },
                          ),
                        ),
                      );
                    },
                    child: Container(
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
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              ref.read(tasksProvider.notifier).toggleTask(task.id);
                            },
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: task.isCompleted ? color : (isDark ? const Color(0xFF121212) : Colors.white),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: task.isCompleted ? color : (isDark ? Colors.grey[700]! : AppColors.divider),
                                  width: 2,
                                ),
                              ),
                              child: task.isCompleted
                                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    decoration: task.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (task.description.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    task.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 13, color: color),
                                    const SizedBox(width: 4),
                                    Text(
                                      task.timeOfDay,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        task.category,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Energy Rating (Bolts)
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          Icons.bolt,
                                          size: 14,
                                          color: index < task.energyRequired
                                              ? AppColors.warning
                                              : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 80),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildCategoryTab(String category) {
    final isActive = _selectedCategory == category;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : (isDark ? Colors.grey[800]! : AppColors.divider),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          category,
          style: TextStyle(
            color: isActive ? Colors.white : (isDark ? Colors.grey[400] : AppColors.textSecondary),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class AddTaskForm extends ConsumerStatefulWidget {
  const AddTaskForm({super.key});

  @override
  ConsumerState<AddTaskForm> createState() => _AddTaskFormState();
}

class _AddTaskFormState extends ConsumerState<AddTaskForm> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'Mengajar';
  int _energyRequired = 3;
  String _timeOfDay = 'Pagi';
  bool _hasTime = false;
  String _startTime = '08:00';
  String _endTime = '09:00';
  bool _isRecurring = false;

  final List<String> _categories = ['Mengajar', 'Les', 'Pribadi', 'Olahraga'];
  final List<String> _times = ['Pagi', 'Siang', 'Sore', 'Malam'];

  String _getEnergyLabel(int energy) {
    switch (energy) {
      case 1:
        return 'Sangat Ringan';
      case 2:
        return 'Ringan';
      case 3:
        return 'Sedang';
      case 4:
        return 'Cukup Berat';
      case 5:
        return 'Sangat Berat';
      default:
        return 'Sedang';
    }
  }

  Widget _buildTimeBox(String label, String time, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Standard keyboard offset handler
    final keyboardOffset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 20, 16, 16 + keyboardOffset),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tambah Tugas Baru',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Judul Tugas',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: 'Keterangan (Opsional)',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Chips
            Text(
              'Kategori',
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _categories.map((cat) {
                final isSelected = _category == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: AppColors.primaryLight,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _category = cat;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Time of Day
            Text(
              'Waktu Pengerjaan',
              style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _times.map((time) {
                final isSelected = _timeOfDay == time;
                return ChoiceChip(
                  label: Text(time),
                  selected: isSelected,
                  selectedColor: AppColors.accentLight,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _timeOfDay = time;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Energy Rating (Bolt selector)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tingkat Energi',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                Text(
                  _getEnergyLabel(_energyRequired),
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final rating = index + 1;
                final isSelected = rating <= _energyRequired;
                return IconButton(
                  icon: Icon(
                    Icons.bolt,
                    color: isSelected ? AppColors.warning : (isDark ? Colors.grey[800] : Colors.grey[200]),
                    size: 36,
                  ),
                  onPressed: () {
                    setState(() {
                      _energyRequired = rating;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 20),

            // Schedule options (optional time + recurring)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle: Ada Jam Spesifik
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Jam Spesifik',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Switch(
                        value: _hasTime,
                        onChanged: (val) => setState(() => _hasTime = val),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),

                  if (_hasTime) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final parts = _startTime.split(':');
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: int.parse(parts[0]),
                                  minute: int.parse(parts[1]),
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  _startTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                });
                              }
                            },
                            child: _buildTimeBox('Mulai', _startTime, context),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final parts = _endTime.split(':');
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: int.parse(parts[0]),
                                  minute: int.parse(parts[1]),
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  _endTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                });
                              }
                            },
                            child: _buildTimeBox('Selesai', _endTime, context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Toggle: Ulang Tiap Hari
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ulang Tiap Hari',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'Muncul di dashboard setiap hari',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isRecurring,
                          onChanged: (val) => setState(() => _isRecurring = val),
                          activeColor: AppColors.accent,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Judul tugas tidak boleh kosong')),
                    );
                    return;
                  }

                  final newTask = TaskModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: title,
                    description: _descController.text.trim(),
                    isCompleted: false,
                    date: DateTime.now(),
                    category: _category,
                    energyRequired: _energyRequired,
                    timeOfDay: _timeOfDay,
                    startTime: _hasTime ? _startTime : null,
                    endTime: _hasTime ? _endTime : null,
                    isRecurring: _isRecurring,
                  );

                  ref.read(tasksProvider.notifier).addTask(newTask);
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tugas "$title" berhasil ditambahkan!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Simpan Tugas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
