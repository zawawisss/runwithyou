import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class AiChatNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() {
    return [
      ChatMessage(
        id: 'init',
        text: 'Halo! Aku asisten AI RunWithYou. 🌸\n\nAda yang bisa kubantu hari ini? Kamu bisa memintaku untuk:\n• Membuat tugas baru (contoh: "tolong buat tugas mengajar biologi")\n• Mengatur jadwal les/mengajar (contoh: "buat jadwal les malam ini jam 19.00")\n• Meminta tips kebugaran setelah mengajar.',
        isUser: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    ];
  }

  void sendMessage(String text) {
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];
  }

  void addAiResponse(String text) {
    final aiMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString() + '_ai',
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = [...state, aiMsg];
  }
}

final aiChatProvider = NotifierProvider<AiChatNotifier, List<ChatMessage>>(AiChatNotifier.new);
