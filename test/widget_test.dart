import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:runwithyou/main.dart';
import 'package:runwithyou/services/hive_service.dart';

void main() {
  testWidgets('RunWithYouApp smoke test', (WidgetTester tester) async {
    // Mock platform channels to avoid hangs in headless environment
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      return null;
    });

    // Mock health package channel (uses 'flutter_health')
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_health'),
            (MethodCall methodCall) async {
      return true;
    });

    // Mock notification channel
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (MethodCall methodCall) async {
      return null;
    });

    // Setup temporary directory for Hive in tests
    final tempDir = Directory.systemTemp.createTempSync();
    await HiveService.init(tempDir.path);

    await tester.pumpWidget(
      const ProviderScope(
        child: RunWithYouApp(),
      ),
    );
    // Use pump instead of pumpAndSettle to avoid hanging on periodic timers (metricsProvider)
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(RunWithYouApp), findsOneWidget);

    // Lepas widget tree supaya ProviderScope di-dispose → Timer.periodic
    // milik metricsProvider di-cancel via ref.onDispose (menghindari error
    // "A Timer is still pending" saat test selesai).
    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    // Clean up
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });
}
