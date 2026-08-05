import 'package:flutter/material.dart';
import 'utils/theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/jogging_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/profile_screen.dart';
import 'providers/health_connect_provider.dart';
import 'screens/ai_chat_screen.dart';
import 'services/health_service.dart';
import 'services/notification_service.dart';
import 'services/openai_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/hive_service.dart';

import 'providers/theme_provider.dart';
import 'providers/tab_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Muat konfigurasi AI dari .env (opsional — kalau file tidak ada, tetap jalan).
  await dotenv.load(isOptional: true);
  await HiveService.init();
  // Muat konfigurasi AI (Hive → .env → default) sebelum UI tampil, supaya
  // AI chat sudah siap meski user belum pernah membuka tab Profil.
  OpenAiService.loadConfig();
  await HealthService.init();
  await NotificationService.init();
  await NotificationService.requestPermission();

  runApp(
    const ProviderScope(
      child: RunWithYouApp(),
    ),
  );
}

class RunWithYouApp extends ConsumerWidget {
  const RunWithYouApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp(
      title: 'RunWithYou',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    // Request Health Connect permission after first frame, then auto-sync
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final granted = await ref.read(healthConnectProvider.notifier).requestPermissions();
      if (granted) {
        // Auto-sync immediately so status badge shows "tersinkron" without manual tap
        await ref.read(healthConnectProvider.notifier).syncToday();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(tabIndexProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      const DashboardScreen(),
      const TasksScreen(),
      const JoggingScreen(),
      const ProgressScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: screens[currentIndex]),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.accent, Color(0xFF45B7A0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AiChatScreen()),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) {
              ref.read(tabIndexProvider.notifier).state = index;
            },
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.task_outlined),
                activeIcon: Icon(Icons.task),
                label: 'Tugas',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.directions_run_outlined),
                activeIcon: Icon(Icons.directions_run),
                label: 'Jogging',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Progress',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
