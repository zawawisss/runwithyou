import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/theme.dart';
import '../providers/tab_provider.dart';

/// Placeholder yang tampil selama Health Connect belum memiliki data nyata
/// (langkah, kalori, detak jantung, tidur) — mis. sebelum bridge "Health Sync"
/// terpasang di HP. Tombolnya mengarah ke tab Profil, tempat dialog Health
/// Connect (4 langkah Health Sync) sudah tersedia.
class HealthComingSoonCard extends ConsumerWidget {
  const HealthComingSoonCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite_outline, color: Colors.white, size: 28),
          const SizedBox(height: 12),
          const Text(
            'Fitur Kesehatan — Segera Hadir',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Data langkah, kalori, detak jantung & tidur akan tampil otomatis '
            'setelah Health Connect terhubung ke smartwatch-mu.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                ref.read(tabIndexProvider.notifier).state = 4;
              },
              icon: const Icon(Icons.link, size: 18),
              label: const Text(
                'Hubungkan Health Connect',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
