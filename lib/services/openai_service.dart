import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'hive_service.dart';

/// Klien chat endpoint OpenAI-compatible (OpenAI, OpenRouter, Groq, Ollama, dll).
/// Sumber konfigurasi, prioritas tertinggi dulu:
///   1. Simpanan in-app (Hive) — diisi lewat Profil > Asisten AI
///   2. File `.env` (flutter_dotenv) — `OPENAI_BASE_URL`, `OPENAI_MODEL`, `OPENAI_API_KEY`
class OpenAiService {
  static String? _baseUrl;
  static String? _model;
  static String? _apiKey;

  static String get baseUrl => _baseUrl ?? '';
  static String get model => _model ?? '';
  static String? get apiKey => _apiKey;

  /// Muat konfigurasi (Hive → .env) ke runtime. Dipanggil oleh `aiConfigProvider`.
  static void loadConfig() {
    _baseUrl = _firstNonEmpty(
      HiveService.getAiBaseUrl(),
      _env('OPENAI_BASE_URL'),
    );
    _model = _firstNonEmpty(
      HiveService.getAiModel(),
      _env('OPENAI_MODEL'),
    );
    _apiKey = _firstNonEmpty(
      HiveService.getAiApiKey(),
      _env('OPENAI_API_KEY'),
    );
    _baseUrl = _baseUrl == null ? null : _normalizeBaseUrl(_baseUrl!);
  }

  static void setConfig({
    required String baseUrl,
    required String model,
    required String apiKey,
  }) {
    _baseUrl = _normalizeBaseUrl(baseUrl.trim());
    _model = model.trim().isEmpty ? null : model.trim();
    _apiKey = apiKey.trim().isEmpty ? null : apiKey.trim();
  }

  // Terkonfigurasi cukup dengan API key (base URL & model boleh kosong,
  // nanti di-cek saat chat dipanggil).
  static bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Ambil nilai non-empty pertama (null kalau semua kosong/null).
  static String? _firstNonEmpty(String? a, String? b) {
    if (a != null && a.isNotEmpty) return a;
    if (b != null && b.isNotEmpty) return b;
    return null;
  }

  /// Baca variabel dari `.env`. Return null kalau belum di-load / kosong.
  static String? _env(String name) {
    if (!dotenv.isInitialized) return null;
    final v = dotenv.maybeGet(name);
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Hilangkan trailing slash dan strip suffix `/chat/completions` bila user
  /// menempel endpoint lengkap. Contoh: `https://openrouter.ai/api/v1/` →
  /// `https://openrouter.ai/api/v1`.
  static String _normalizeBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/chat/completions')) {
      u = u.substring(0, u.length - '/chat/completions'.length);
    }
    return u;
  }

  /// Chat completion (non-streaming) ke `{baseUrl}/chat/completions`.
  static Future<String> chat({
    required List<Map<String, String>> messages,
    String? model,
    double temperature = 0.7,
    int maxTokens = 800,
  }) async {
    if (!isConfigured) {
      throw Exception(
          'API key AI belum diisi. Atur di Profil > Asisten AI.');
    }
    final resolvedModel = model ?? OpenAiService.model;
    if (resolvedModel.isEmpty) {
      throw Exception('Model AI belum diatur. Atur di Profil > Asisten AI.');
    }
    final resolvedBaseUrl = OpenAiService.baseUrl;
    if (resolvedBaseUrl.isEmpty) {
      throw Exception('Base URL AI belum diatur. Atur di Profil > Asisten AI.');
    }

    try {
      final response = await Dio().post(
        '$resolvedBaseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': resolvedModel,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
        },
      );

      final content = response.data['choices']?[0]?['message']?['content']
          as String?;
      if (content == null) {
        throw Exception('Respon AI kosong');
      }
      return content;
    } on DioException catch (e) {
      debugPrint(
          'OpenAI-compatible API error: ${e.response?.statusCode} ${e.message}');
      throw Exception(
          'Gagal terhubung: ${e.response?.statusCode ?? e.message}');
    }
  }
}
