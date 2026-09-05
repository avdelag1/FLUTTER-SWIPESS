import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/providers/supabase_provider.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';

// GlowSearchBar consumes both editable dashboard copy and the discovery
// location context used by its inline AI request. Re-export the provider here
// so the app-copy refactor does not accidentally sever that existing context.
export 'package:flutter_swipes/src/features/dashboard/presentation/providers/discovery_location_provider.dart'
    show discoveryLocationProvider;

/// Editable dashboard AI hints. Each non-empty line becomes one rotating hint.
/// The local default keeps the field useful if the device is offline or the
/// configuration table has not reached an older backend yet.
const defaultDashboardAiPrompts = <String>[
  'What are you looking for?',
  'Craving hot pizza right now?',
  'Want fresh flowers you can almost smell?',
  'Need a chauffeur for a smooth ride?',
  'Ready for a relaxing massage?',
  'Looking for a beach house with an ocean view?',
  'Want a yacht escape with salt air and sunset?',
  'Hungry for a private chef tonight?',
  'Looking for live music and a night out?',
  'Need someone local to make life easier?',
];

final dashboardAiPromptsProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return defaultDashboardAiPrompts;

  try {
    final row = await ref
        .read(supabaseClientProvider)
        .from('app_copy')
        .select('value')
        .eq('key', 'dashboard_ai_prompts')
        .maybeSingle();
    final raw = row?['value']?.toString() ?? '';
    final prompts = raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(12)
        .toList(growable: false);
    if (prompts.isEmpty) return defaultDashboardAiPrompts;
    final merged = <String>[];
    final seen = <String>{};
    for (final prompt in <String>[...prompts, ...defaultDashboardAiPrompts]) {
      if (seen.add(prompt.toLowerCase())) merged.add(prompt);
      if (merged.length == 10) break;
    }
    return merged;
  } catch (_) {
    return defaultDashboardAiPrompts;
  }
});
