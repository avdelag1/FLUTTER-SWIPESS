import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/payments/data/payment_service.dart';

class NativeSwipeApp extends ConsumerWidget {
  const NativeSwipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(revenueCatAuthSyncProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Swipess',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
