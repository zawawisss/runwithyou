import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/theme.dart';
import '../providers/theme_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/health_connect_provider.dart';
import '../providers/ai_config_provider.dart';
import '../services/health_service.dart';
import '../services/hive_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final profile = ref.watch(profileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profil',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // Profile Card
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Settings List
          _buildSettingsSection(
            context,
            children: [
              _buildSettingsItem(
                context,
                icon: Icons.person_outline,
                title: 'Edit Profil',
                onTap: () {
                  _showEditProfileDialog(context, ref, profile);
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.notifications_outlined,
                title: 'Notifikasi',
                onTap: () {
                  _showNotificationsDialog(context);
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.monitor_heart_outlined,
                title: 'Health Connect',
                trailing: _buildHealthSyncIndicator(ref),
                onTap: () {
                  _showHealthConnectDialog(context, ref);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsSection(
            context,
            children: [
              _buildSettingsItem(
                context,
                icon: Icons.smart_toy_outlined,
                title: 'Asisten AI',
                trailing: _buildAiConfigStatus(context, ref),
                onTap: () {
                  _showAiConfigDialog(context, ref);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsSection(
            context,
            children: [
              _buildSettingsItem(
                context,
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                trailing: Switch(
                  value: isDarkMode,
                  onChanged: (value) {
                    ref.read(themeProvider.notifier).toggleTheme();
                  },
                  activeColor: AppColors.primary,
                ),
                onTap: () {
                  ref.read(themeProvider.notifier).toggleTheme();
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.language,
                title: 'Bahasa',
                trailing: const Text(
                  'Indonesia',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  _showLanguageDialog(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSettingsSection(
            context,
            children: [
              _buildSettingsItem(
                context,
                icon: Icons.help_outline,
                title: 'Bantuan',
                onTap: () {
                  _showHelpDialog(context);
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.info_outline,
                title: 'Tentang Aplikasi',
                onTap: () {
                  _showAboutDialog(context);
                },
              ),
              _buildSettingsItem(
                context,
                icon: Icons.star_outline,
                title: 'Beri Rating',
                onTap: () {
                  _showRatingDialog(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // App Version
          const Center(
            child: Text(
              'RunWithYou v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Langkah bersama menuju sehat & bahagia',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context, {required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiConfigStatus(BuildContext context, WidgetRef ref) {
    final config = ref.watch(aiConfigProvider);
    if (config.isConfigured) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Tersimpan',
            style: TextStyle(fontSize: 14, color: AppColors.accent),
          ),
          SizedBox(width: 4),
          Icon(Icons.check_circle, size: 16, color: AppColors.accent),
        ],
      );
    }
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Belum diatur',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        SizedBox(width: 4),
        Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
      ],
    );
  }

  InputDecoration _aiInputDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  void _showAiConfigDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = ref.read(aiConfigProvider);

    final baseUrlController = TextEditingController(text: config.baseUrl);
    final modelController = TextEditingController(text: config.model);
    final apiKeyController = TextEditingController(text: config.apiKey);
    var obscureKey = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                  16, 20, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
                      'Konfigurasi Asisten AI',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pakai endpoint OpenAI-compatible (OpenRouter, OpenAI, '
                      'Groq, Ollama, dll). Key disimpan lokal di perangkat.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark
                            ? Colors.grey[400]
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: baseUrlController,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: _aiInputDecoration(
                        label: 'Base URL',
                        hint: 'https://openrouter.ai/api/v1',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: modelController,
                      autocorrect: false,
                      decoration: _aiInputDecoration(
                        label: 'Model (opsional)',
                        hint: 'contoh: meta-llama/llama-3.1-70b-instruct',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: apiKeyController,
                      obscureText: obscureKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: _aiInputDecoration(
                        label: 'API Key',
                        hint: 'sk-...',
                      ).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureKey
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () {
                            setDialogState(() => obscureKey = !obscureKey);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(aiConfigProvider.notifier)
                                .saveConfig(
                                  baseUrl: baseUrlController.text,
                                  model: modelController.text,
                                  apiKey: apiKeyController.text,
                                );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Konfigurasi AI tersimpan ✅'),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Simpan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, ProfileState profile) {
    final nameController = TextEditingController(text: profile.name);
    final goalController = TextEditingController(text: profile.stepGoal.toString());
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
                  'Edit Profil',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap/Panggilan',
                    hintText: 'Masukkan nama Anda',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: goalController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Target Langkah Harian',
                    hintText: 'Contoh: 8000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final newName = nameController.text.trim();
                      final newGoal = int.tryParse(goalController.text.trim()) ?? profile.stepGoal;
                      if (newName.isNotEmpty) {
                        ref.read(profileProvider.notifier).updateProfile(
                          name: newName,
                          stepGoal: newGoal,
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profil berhasil diperbarui!')),
                        );
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
  }

  void _showNotificationsDialog(BuildContext context) {
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
              'Pengaturan Notifikasi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              'Notifikasi pintar diaktifkan secara otomatis. Anda akan menerima pengingat jogging sebelum jadwal les malam atau sekolah dimulai.',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSyncIndicator(WidgetRef ref) {
    final healthState = ref.watch(healthConnectProvider);
    switch (healthState.status) {
      case HealthSyncStatus.syncing:
        return const SizedBox(
          width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case HealthSyncStatus.success:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppColors.accent, size: 16),
            SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        );
      case HealthSyncStatus.noPermission:
      case HealthSyncStatus.error:
        return const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 16),
            SizedBox(width: 4),
            Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        );
      default:
        return const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20);
    }
  }

  void _showHealthConnectDialog(BuildContext context, WidgetRef ref) {
    final healthState = ref.read(healthConnectProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.monitor_heart, color: AppColors.accent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Health Connect',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sync data dari jam tangan / smartwatch kamu',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.accent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Cara kerja:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[300] : Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildStep(isDark, '1', 'Buka app Huawei Health, pastikan band tersinkron'),
                    _buildStep(isDark, '2', 'Aktifkan Cloud Huawei (Saya > Manajemen Privasi)'),
                    _buildStep(isDark, '3', 'Install "Health Sync" → pilih Huawei Health → Health Connect'),
                    _buildStep(isDark, '4', 'Izinkan akses, lalu kembali ke sini & tekan "Sync Sekarang"'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (healthState.lastSync != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.schedule, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        'Terakhir sync: ${_formatSyncTime(healthState.lastSync!)}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              if (healthState.message != null && healthState.status != HealthSyncStatus.syncing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    healthState.message!,
                    style: TextStyle(
                      fontSize: 13,
                      color: healthState.status == HealthSyncStatus.success
                          ? AppColors.accent
                          : AppColors.warning,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Consumer(
                builder: (context, ref, _) {
                  final syncState = ref.watch(healthConnectProvider);
                  return SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: syncState.status == HealthSyncStatus.syncing
                          ? null
                          : () async {
                              final hasPerm = await HealthService.checkPermissions();
                              if (!hasPerm) {
                                await ref.read(healthConnectProvider.notifier).requestPermissions();
                              }
                              if (context.mounted) {
                                await ref.read(healthConnectProvider.notifier).syncToday();
                              }
                            },
                      icon: syncState.status == HealthSyncStatus.syncing
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync, size: 20),
                      label: Text(
                        syncState.status == HealthSyncStatus.syncing
                            ? 'Menyinkronkan...'
                            : 'Sync Sekarang',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: TextButton.icon(
                  onPressed: () => _showDiagnosticsDialog(context),
                  icon: const Icon(Icons.bug_report, size: 18, color: AppColors.primary),
                  label: const Text(
                    'Lihat Log Diagnostik',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF242424) : Colors.grey[100],
                    foregroundColor: isDark ? Colors.grey[300] : AppColors.textSecondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep(bool isDark, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }

  void _showDiagnosticsDialog(BuildContext context) {
    final logs = HiveService.getDiagnosticsLogs();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Log Diagnostik Sync'),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () async {
                  await HiveService.clearDiagnosticsLogs();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Log diagnostik dibersihkan')),
                    );
                  }
                },
              )
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: logs.isEmpty
                ? const Center(child: Text('Belum ada log sinkronisasi.'))
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isError = log.contains('failed') || log.contains('error') || log.contains('Exception');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: isError ? Colors.red : Colors.green[700],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await HealthService.dumpAvailableData();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dump data selesai — buka lagi log ini untuk melihat hasilnya')),
                  );
                }
              },
              child: const Text('Dump Data'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
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
              'Bahasa',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              'Bahasa aplikasi saat ini disetel ke Bahasa Indonesia.',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
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
              'Bantuan & Dukungan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              'Hubungi tim dukungan kami melalui email di support@runwithyou.com jika Anda mengalami kendala sinkronisasi jam tangan.',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
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
              'Tentang RunWithYou',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              'Aplikasi khusus penyeimbang aktivitas mengajar guru yang padat dengan olahraga teratur demi menjaga tingkat kesehatan harian.',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
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
              'Beri Rating',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(
              'Terima kasih banyak atas dukungannya! Rating Anda membantu kami berdua tetap sehat dan bahagia.',
              style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Sama-sama! ❤️'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
