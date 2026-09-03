import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialConnection {
  const SocialConnection({
    required this.provider,
    required this.accountName,
    this.accountId,
  });

  final String provider;
  final String accountName;
  final String? accountId;

  factory SocialConnection.fromJson(Map<String, dynamic> row) =>
      SocialConnection(
        provider: row['provider']?.toString() ?? '',
        accountName:
            row['provider_account_name']?.toString().trim().isNotEmpty == true
            ? row['provider_account_name'].toString().trim()
            : row['provider']?.toString() ?? 'Connected account',
        accountId: row['provider_account_id']?.toString(),
      );
}

class SocialDistributionState {
  const SocialDistributionState({
    this.connections = const <SocialConnection>[],
    this.autoPublish = false,
    this.providers = const <String>{},
  });

  final List<SocialConnection> connections;
  final bool autoPublish;
  final Set<String> providers;

  bool connected(String provider) =>
      connections.any((connection) => connection.provider == provider);

  SocialConnection? connectionFor(String provider) {
    for (final connection in connections) {
      if (connection.provider == provider) return connection;
    }
    return null;
  }
}

class SocialDistributionService {
  SocialDistributionService(this._client);

  final SupabaseClient _client;

  Future<SocialDistributionState> loadState() async {
    final user = _client.auth.currentUser;
    if (user == null) return const SocialDistributionState();

    final rows = await _client
        .from('social_connections')
        .select('provider, provider_account_id, provider_account_name')
        .eq('user_id', user.id);
    final connections = (rows as List)
        .whereType<Map>()
        .map((row) => SocialConnection.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);

    final pref = await _client
        .from('social_distribution_preferences')
        .select('auto_publish, providers')
        .eq('user_id', user.id)
        .maybeSingle();

    final providerValues = pref?['providers'];
    final providers = providerValues is List
        ? providerValues.map((e) => e.toString()).toSet()
        : <String>{};

    return SocialDistributionState(
      connections: connections,
      autoPublish: pref?['auto_publish'] == true,
      providers: providers,
    );
  }

  Future<void> savePreferences({
    required bool autoPublish,
    required Set<String> providers,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Sign in to manage Social Boost.');
    final safeProviders = providers
        .where(
          (p) =>
              const {'instagram', 'facebook', 'tiktok', 'youtube'}.contains(p),
        )
        .toList(growable: false);
    await _client.from('social_distribution_preferences').upsert({
      'user_id': user.id,
      'auto_publish': autoPublish,
      'providers': safeProviders,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Uri> startConnect(String provider) async {
    try {
      final response = await _client.functions.invoke(
        'social-connect-start',
        body: {'provider': provider},
      );
      final data = response.data;
      if (data is Map && data['auth_url'] != null) {
        final uri = Uri.tryParse(data['auth_url'].toString());
        if (uri != null) return uri;
      }
      throw StateError('Social provider setup is not complete yet.');
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['missing'] is List) {
        final missing = (details['missing'] as List).join(', ');
        throw StateError(
          'Swipess still needs the provider credentials: $missing.',
        );
      }
      rethrow;
    }
  }

  Future<void> connect(String provider) async {
    final uri = await startConnect(provider);
    final opened = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      webOnlyWindowName: kIsWeb ? '_self' : null,
    );
    if (!opened)
      throw StateError('Could not open the $provider authorization page.');
  }

  Future<void> disconnect(String provider) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('social_connections')
        .delete()
        .eq('user_id', user.id)
        .eq('provider', provider);
  }

  /// Fire-and-forget after a listing is successfully created. The Edge Function
  /// independently checks the user's opt-in preference and connected providers,
  /// so publishing a listing never blocks on social network latency.
  void distributeListingInBackground(String listingId) {
    unawaited(() async {
      try {
        await _client.functions.invoke(
          'social-distribute',
          body: {'listing_id': listingId},
        );
      } catch (error) {
        debugPrint('Organic social distribution skipped: $error');
      }
    }());
  }
}

final socialDistributionServiceProvider = Provider<SocialDistributionService>((
  ref,
) {
  return SocialDistributionService(Supabase.instance.client);
});

final socialDistributionStateProvider = FutureProvider<SocialDistributionState>(
  (ref) {
    return ref.read(socialDistributionServiceProvider).loadState();
  },
);
