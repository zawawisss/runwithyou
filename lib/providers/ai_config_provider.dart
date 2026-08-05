import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hive_service.dart';
import '../services/openai_service.dart';

class AiConfigState {
  final String baseUrl;
  final String model;
  final String apiKey;

  AiConfigState({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  // Cukup API key — base URL & model punya default kode/`.env` dan divalidasi
  // lagi di `OpenAiService.chat()` dengan pesan error yang jelas.
  bool get isConfigured => OpenAiService.isConfigured;
}

class AiConfigNotifier extends Notifier<AiConfigState> {
  @override
  AiConfigState build() {
    OpenAiService.loadConfig();
    // Baca dari service supaya default kode (base URL & model) ikut terlihat.
    return AiConfigState(
      baseUrl: OpenAiService.baseUrl,
      model: OpenAiService.model,
      apiKey: OpenAiService.apiKey ?? '',
    );
  }

  Future<void> saveConfig({
    required String baseUrl,
    required String model,
    required String apiKey,
  }) async {
    final trimmedUrl = baseUrl.trim();
    final trimmedModel = model.trim();
    final trimmedKey = apiKey.trim();

    if (trimmedUrl.isEmpty || trimmedKey.isEmpty) {
      throw Exception('Base URL dan API key wajib diisi');
    }

    await HiveService.saveAiBaseUrl(trimmedUrl);
    await HiveService.saveAiModel(trimmedModel);
    await HiveService.saveAiApiKey(trimmedKey);

    OpenAiService.setConfig(
      baseUrl: trimmedUrl,
      model: trimmedModel,
      apiKey: trimmedKey,
    );

    // Pakai getter service supaya model kosong yang disimpan otomatis
    // tertimpa default kode.
    state = AiConfigState(
      baseUrl: OpenAiService.baseUrl,
      model: OpenAiService.model,
      apiKey: OpenAiService.apiKey ?? '',
    );
  }
}

final aiConfigProvider =
    NotifierProvider<AiConfigNotifier, AiConfigState>(AiConfigNotifier.new);
