import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/openai_service.dart';
import 'ai_config_provider.dart';
import 'energy_provider.dart';
import 'metrics_provider.dart';
import 'tasks_provider.dart';
import 'profile_provider.dart';
import 'workout_provider.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class AiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final bool isConfigured;

  const AiChatState({
    required this.messages,
    this.isLoading = false,
    this.error,
    this.isConfigured = false,
  });

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isConfigured,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }
}

class AiChatNotifier extends Notifier<AiChatState> {
  static const _welcomeId = 'init';
  static const _maxHistory = 10;

  @override
  AiChatState build() {
    // Ikuti perubahan konfigurasi AI (Profil > Asisten AI) supaya
    // state.isConfigured selalu sinkron — termasuk kalau key diatur setelah
    // user pernah membuka chat.
    ref.watch(aiConfigProvider);
    return AiChatState(
      messages: [_welcomeMessage()],
      isConfigured: OpenAiService.isConfigured,
    );
  }

  ChatMessage _welcomeMessage() => ChatMessage(
        id: _welcomeId,
        text: 'Halo! Aku asisten AI RunWithYou. 🌸\n\n'
            'Ada yang bisa kubantu hari ini? Kamu bisa memintaku untuk:\n'
            '• Rekomendasi olahraga & jogging yang pas dengan energimu\n'
            '• Saran mengatur jadwal mengajar/les yang padat\n'
            '• Motivasi & tips kebugaran harian\n'
            '• Analisis progress mingguanmu',
        isUser: false,
        timestamp: DateTime.now(),
      );

  /// Hapus seluruh percakapan, kembalikan ke pesan sambutan.
  void clearChat() {
    state = AiChatState(
      messages: [_welcomeMessage()],
      isConfigured: OpenAiService.isConfigured,
    );
  }

  /// Kirim pesan user → panggil `OpenAiService.chat()` → tampilkan balasan AI.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isLoading) return;

    if (!OpenAiService.isConfigured) {
      state = state.copyWith(
        error:
            'Asisten AI belum diatur. Atur API key dulu di Profil > Asisten AI.',
      );
      return;
    }

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      clearError: true,
    );

    try {
      final reply = await OpenAiService.chat(messages: _toApiMessages());
      final aiMsg = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isLoading: false,
      );
    } catch (e) {
      // UI tetap responsif; error ditampilkan sebagai bubble merah.
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Pesan untuk API: system prompt + riwayat terakhir (pesan welcome diskip).
  List<Map<String, String>> _toApiMessages() {
    final history = state.messages.where((m) => m.id != _welcomeId).toList();
    final recent = history.length > _maxHistory
        ? history.sublist(history.length - _maxHistory)
        : history;

    return [
      {'role': 'system', 'content': _buildSystemPrompt()},
      ...recent.map((m) => {
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.text,
          }),
    ];
  }

  /// Konteks dinamis Fitri (energi, metrik, jadwal, jogging) untuk prompt AI.
  String _buildSystemPrompt() {
    final profile = ref.read(profileProvider);
    final energy = ref.read(energyProvider);
    final metrics = ref.read(metricsProvider);
    final tasks = ref.read(tasksProvider);
    final workouts = ref.read(workoutProvider);

    final now = DateTime.now();
    final todayTasks = tasks
        .where((t) =>
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day)
        .toList();

    final metricParts = [
      if (metrics.sleepHours != null)
        'Tidur ${metrics.sleepHours!.toStringAsFixed(1)} jam',
      if (metrics.steps != null) '${metrics.steps} langkah',
      if (metrics.calories != null) '${metrics.calories} kcal',
      if (metrics.averageHeartRate != null)
        'HR rata-rata ${metrics.averageHeartRate} bpm',
    ];

    final taskLines = todayTasks.isEmpty
        ? 'Tidak ada tugas tercatat untuk hari ini.'
        : todayTasks
            .map((t) {
              final time = t.hasTime ? ' (${t.startTime}–${t.endTime})' : '';
              final status = t.isCompleted ? '✅ selesai' : '⏳ belum selesai';
              return '• ${t.title}$time [${t.category}] — $status';
            })
            .join('\n');

    final recentWorkouts = workouts.take(3).map((w) {
      final dur = '${w.duration ~/ 60} mnt';
      final d = w.date.day.toString().padLeft(2, '0');
      final mo = w.date.month.toString().padLeft(2, '0');
      return '• $d/$mo: ${w.distance.toStringAsFixed(1)} km, $dur, ${w.calories} kcal';
    }).join('\n');

    return '''
Kamu adalah "Asisten RunWithYou" — asisten kesehatan & produktivitas pribadi ${profile.name}, seorang guru perempuan yang sibuk mengajar di sekolah dan les malam. Jawab dalam Bahasa Indonesia yang hangat, ramah, dan suportif; panggil pengguna dengan "kamu". Jangan berlebihan memakai emoji.

Konteks hari ini:
- Energi: ${energy.percentage}% (${energy.statusMessage})
- ${metricParts.isEmpty ? 'Belum ada data kesehatan tercatat.' : metricParts.join(', ')}
- Target langkah: ${profile.stepGoal}
- Jadwal & tugas hari ini:
$taskLines
- Jogging terakhir:
${recentWorkouts.isEmpty ? 'Belum ada riwayat jogging.' : recentWorkouts}

Tugasmu:
1. Beri rekomendasi olahraga & jadwal yang realistis sesuai energi dan jadwal di atas.
2. Beri motivasi personal yang hangat.
3. Analisis progress mingguan (langkah, kalori, tidur, jogging) bila ditanya.
Jawab ringkas (2–4 kalimat) kecuali pengguna minta detail.
''';
  }
}

final aiChatProvider =
    NotifierProvider<AiChatNotifier, AiChatState>(AiChatNotifier.new);
