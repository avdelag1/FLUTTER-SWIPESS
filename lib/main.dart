import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/config/app_config.dart';
import 'package:flutter_swipes/src/core/services/supabase_service.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/ai_providers.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();

  final container = ProviderContainer();
  final userId = SupabaseService.client.auth.currentUser?.id;
  await container.read(paymentServiceProvider).init(userId: userId);

  if (AppConfig.hasOpenAiKey) {
    container.read(aiBrainConfigProvider.notifier).setOpenAiKey(
          AppConfig.openAiApiKey,
        );
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const NativeSwipeApp(),
    ),
  );
}
