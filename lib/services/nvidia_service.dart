import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/task.dart';

class NvidiaService {
  static const String _baseUrl = 'https://integrate.api.nvidia.com/v1/chat/completions';
  static const String _model = 'meta/llama-3.1-70b-instruct';
  static String? _apiKey;

  static void setApiKey(String key) => _apiKey = key;
  static bool get hasKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Parse WhatsApp/plain text into tasks via NVIDIA NIM.
  /// Returns list of parsed tasks preview (without ID, not saved yet).
  static Future<List<ParsedTask>> parseTasks(String text) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('API key NVIDIA NIM belum diatur');
    }

    const systemPrompt = 'Input: text. Output: JSON array {title, category, energy(1-5)}. Kategori: Mengajar/Les/Pribadi/Olahraga. Langsung JSON aja.';

    try {
      final response = await Dio().post(
        _baseUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': text},
          ],
          'temperature': 0.1,
          'max_tokens': 500,
        },
      );

      final content = response.data['choices']?[0]?['message']?['content'] as String?;
      if (content == null) {
        throw Exception('Respon AI kosong');
      }

      // Strip markdown code fences if present
      final clean = content
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
          .trim();

      final List<dynamic> items = jsonDecode(clean) as List<dynamic>;
      return items.map((item) {
        final map = item as Map<String, dynamic>;
        final title = map['title'] as String? ?? 'Tugas tanpa judul';
        final category = map['category'] as String? ?? 'Pribadi';
        final energy = map['energy'] as int? ?? 3;

        // Map time of day based on category/context
        String timeOfDay;
        if (category == 'Mengajar') {
          timeOfDay = 'Pagi';
        } else if (category == 'Les') {
          timeOfDay = 'Malam';
        } else if (category == 'Olahraga') {
          timeOfDay = 'Sore';
        } else {
          timeOfDay = 'Siang';
        }

        return ParsedTask(
          title: title,
          description: '',
          category: _validCategory(category),
          energyRequired: energy.clamp(1, 5),
          timeOfDay: timeOfDay,
        );
      }).toList();
    } on DioException catch (e) {
      debugPrint('NVIDIA NIM API error: ${e.response?.data ?? e.message}');
      throw Exception('Gagal memproses: ${e.response?.statusCode ?? e.message}');
    } on FormatException {
      throw Exception('Respon AI tidak valid, coba lagi');
    }
  }

  static String _validCategory(String cat) {
    const valid = ['Mengajar', 'Les', 'Pribadi', 'Olahraga'];
    return valid.contains(cat) ? cat : 'Pribadi';
  }
}

/// Lightweight preview model — not persisted, just for UI preview before saving.
class ParsedTask {
  final String title;
  final String description;
  final String category;
  final int energyRequired;
  final String timeOfDay;

  ParsedTask({
    required this.title,
    required this.description,
    required this.category,
    required this.energyRequired,
    required this.timeOfDay,
  });

  TaskModel toTask(DateTime date) {
    return TaskModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      isCompleted: false,
      date: date,
      category: category,
      energyRequired: energyRequired,
      timeOfDay: timeOfDay,
    );
  }
}
