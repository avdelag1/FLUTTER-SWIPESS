import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/services/supabase_service.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

final aiEdgeRepositoryProvider = Provider<AiEdgeRepository>((ref) {
  return AiEdgeRepository();
});

/// Cap AI edge functions — keys stay in Supabase Dashboard secrets.
///
/// Cap `useConciergeAI` posts with the user JWT **or** the public anon key and
/// reads SSE (`text/event-stream`) first, then JSON. `functions.invoke` leaves
/// SSE as a live byte stream, so we talk HTTP like Cap and accumulate deltas.
class AiEdgeRepository {
  AiEdgeRepository({SupabaseClient? client, http.Client? httpClient})
    : _client = client ?? Supabase.instance.client,
      _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;

  static const _timeout = Duration(seconds: 60);
  static final _profileIntent = RegExp(
    r'\b(seekers|workers|buyers|renters|people|users|pros|professionals)\b',
    caseSensitive: false,
  );

  bool get isSignedIn => _client.auth.currentUser != null;

  /// Cap `useAIEnhanceText` → `ai-enhance-text`, with concierge fallback.
  Future<String?> enhanceText({
    required String text,
    String type = 'listing',
  }) async {
    final trimmed = text.trim();
    if (trimmed.length < 5) return null;
    try {
      final raw = await _postEdge('ai-enhance-text', {
        'text': trimmed,
        'type': type,
      }, stream: false);
      final out = _parseEnhanceText(raw);
      if (out != null && out.isNotEmpty) return out;
    } on AiUnavailableException {
      // Fall through to concierge architect.
    }
    try {
      final reply = await chatConcierge(
        messages: [
          AiChatMessage(
            role: 'system',
            content: type == 'profile'
                ? 'You are Swipess profile copy. Rewrite the user text into a '
                      'polished, cinematic bio. Return only the bio.'
                : 'You are an elite listing architect for Swipess. Transform '
                      'raw input into a professional, cinematic listing '
                      'description. Return only the description.',
          ),
          AiChatMessage(role: 'user', content: trimmed),
        ],
        character: type == 'profile' ? null : 'listing_architect',
        stream: false,
      );
      return reply.trim().isEmpty ? null : reply.trim();
    } on AiUnavailableException {
      return null;
    }
  }

  /// Cap Intel Core / `useConciergeAI`.
  Future<String> chatConcierge({
    required List<AiChatMessage> messages,
    String? character,
    Map<String, dynamic>? locationContext,
    String? preferredIntent,
    bool stream = true,
  }) async {
    final apiMessages = [
      for (final m in messages)
        if (m.content.trim().isNotEmpty)
          {'role': m.role, 'content': m.content.trim()},
    ];
    if (apiMessages.length > 12) {
      apiMessages.removeRange(0, apiMessages.length - 12);
    }

    final lastUser = messages.reversed
        .where((m) => m.role == 'user')
        .map((m) => m.content)
        .firstOrNull;
    final intent =
        preferredIntent ??
        (lastUser != null && _profileIntent.hasMatch(lastUser)
            ? 'profiles'
            : null);

    final payload = <String, dynamic>{
      'messages': apiMessages,
      'stream': stream,
      if (character != null && character.isNotEmpty) 'character': character,
      if (locationContext != null && locationContext.isNotEmpty)
        'locationContext': locationContext,
      if (intent != null) 'preferredIntent': intent,
    };

    String? reply;
    AiUnavailableException? lastError;
    try {
      reply = _parseConciergeReply(await _postEdge('ai-concierge', payload));
    } on AiUnavailableException catch (e) {
      lastError = e;
    }

    if ((reply == null || reply.isEmpty) && stream) {
      try {
        reply = _parseConciergeReply(
          await _postEdge('ai-concierge', {...payload, 'stream': false}),
        );
      } on AiUnavailableException catch (e) {
        lastError = e;
      }
    }

    final cleaned = _normalizeReply(reply ?? '');
    if (cleaned.isNotEmpty) return cleaned;

    // A live marketplace request must not be reported as an AI outage merely
    // because an upstream model returned an empty body. Query the same Swipess
    // listings directly and return the structured card tag the chat UI already
    // understands. This also makes property discovery independent of model luck.
    final marketplaceFallback = await _structuredMarketplaceFallback(lastUser);
    if (marketplaceFallback != null && marketplaceFallback.isNotEmpty) {
      return marketplaceFallback;
    }

    throw lastError ??
        AiUnavailableException(
          'AI is temporarily unavailable. Try again in a moment.',
        );
  }

  Future<String?> _structuredMarketplaceFallback(String? userText) async {
    final raw = userText?.trim() ?? '';
    if (raw.isEmpty) return null;
    final q = raw.toLowerCase();
    String? category;
    String label = 'listings';

    if (RegExp(
      r'\b(property|properties|home|homes|house|houses|apartment|apartments|room|rooms|studio|studios|villa|villas|condo|condos|rent|rental|buy|sale|casa|casas|departamento|departamentos|renta)\b',
    ).hasMatch(q)) {
      category = 'property';
      label = 'properties';
    } else if (RegExp(r'\b(yacht|yachts|boat|boats|yate|yates)\b').hasMatch(q)) {
      category = 'yacht';
      label = 'yachts';
    } else if (RegExp(
      r'\b(motorcycle|motorcycles|motorbike|motorbikes|moto|motos|scooter|scooters)\b',
    ).hasMatch(q)) {
      category = 'motorcycle';
      label = 'motorcycles';
    } else if (RegExp(r'\b(bicycle|bicycles|bike|bikes|bici|bicicleta)\b').hasMatch(q)) {
      category = 'bicycle';
      label = 'bicycles';
    } else if (RegExp(
      r'\b(worker|workers|service|services|cleaner|chef|driver|plumber|electrician|handyman|mechanic)\b',
    ).hasMatch(q)) {
      category = 'worker';
      label = 'workers';
    }

    if (category == null) return null;

    try {
      final rows = await _client
          .from('listings')
          .select(
            'id,title,price,currency,listing_type,city,neighborhood,category,images',
          )
          .eq('is_active', true)
          .eq('status', 'active')
          .eq('category', category)
          .order('updated_at', ascending: false)
          .limit(3);

      final structured = <Map<String, dynamic>>[];
      for (final rawRow in rows as List) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        String image = '';
        final images = row['images'];
        if (images is List && images.isNotEmpty) {
          final first = images.first;
          if (first is String) {
            image = first;
          } else if (first is Map) {
            image = first['url']?.toString() ?? first['src']?.toString() ?? '';
          }
        }
        structured.add({
          'id': row['id'],
          'title': row['title'],
          'price': row['price'],
          'currency': row['currency'] ?? 'USD',
          'listing_type': row['listing_type'] ?? 'rent',
          'city': row['neighborhood'] ?? row['city'] ?? '',
          'category': row['category'] ?? category,
          'image': image,
        });
      }

      if (structured.isEmpty) {
        return 'No matching $label are live right now. Try another location or filter.';
      }
      return 'I found matching $label for you.\n[LISTINGS:${jsonEncode(structured)}]';
    } catch (_) {
      return null;
    }
  }

  /// Cap `AIListingWizard` → `ai-listing-extract`.
  Future<Map<String, dynamic>> extractListing({
    required String category,
    required String prompt,
    String? city,
    String? price,
  }) async {
    final body = <String, dynamic>{
      'task': 'extract',
      'category': category,
      'prompt': prompt,
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (price != null && price.trim().isNotEmpty) 'price': price.trim(),
    };
    try {
      final data = _asMap(
        await _postEdge('ai-listing-extract', body, stream: false),
      );
      final nested = data['data'];
      if (nested is Map && nested.isNotEmpty) {
        return Map<String, dynamic>.from(nested);
      }
      if (data.containsKey('title') || data.containsKey('description')) {
        return data;
      }
    } on AiUnavailableException {
      // Fall through to concierge extractor.
    }

    try {
      final reply = await chatConcierge(
        messages: [
          AiChatMessage(
            role: 'system',
            content:
                'Extract listing details from the user input for category: '
                '$category. Return ONLY valid JSON.',
          ),
          AiChatMessage(role: 'user', content: prompt),
        ],
        character: 'listing_extractor',
        stream: false,
      );
      return _jsonObjectFromText(reply);
    } on AiUnavailableException {
      return const {};
    }
  }

  /// Cap `AIProfileWizard` → `ai-profile-extract`.
  Future<Map<String, dynamic>> extractProfile({
    required String narrative,
    String mode = 'client',
  }) async {
    try {
      final data = _asMap(
        await _postEdge('ai-profile-extract', {
          'mode': mode,
          'narrative': narrative,
        }, stream: false),
      );
      final profile = data['profile'];
      if (profile is Map && profile.isNotEmpty) {
        return Map<String, dynamic>.from(profile);
      }
      if (data.containsKey('bio') || data.containsKey('name')) {
        return data;
      }
    } on AiUnavailableException {
      // Fall through.
    }
    return const {};
  }

  /// Cap `assertImageSafe` — fails open on infra errors.
  Future<void> assertImageSafe(String imageUrl) async {
    Map<String, dynamic> verdict;
    try {
      verdict = _asMap(
        await _postEdge('moderate-image', {
          'imageUrl': imageUrl,
        }, stream: false),
      );
    } catch (_) {
      return;
    }
    if (verdict['safe'] == false) {
      final reasons = verdict['reasons'];
      final reason = reasons is List && reasons.isNotEmpty
          ? reasons.first.toString()
          : 'it violates our content policy';
      throw AiModerationException(
        "This photo can't be used — $reason. Please choose another.",
      );
    }
  }

  /// POST like Cap `fetch(AI_URL)` so SSE bodies are fully collected as text.
  Future<dynamic> _postEdge(
    String functionName,
    Map<String, dynamic> body, {
    bool stream = true,
  }) async {
    final url = Uri.parse(
      '${SupabaseService.supabaseUrl}/functions/v1/$functionName',
    );
    final token =
        _client.auth.currentSession?.accessToken ?? SupabaseService.anonKey;
    final payload = Map<String, dynamic>.from(body);
    if (!payload.containsKey('stream')) payload['stream'] = stream;

    late http.Response resp;
    try {
      resp = await _http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'apikey': SupabaseService.anonKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } catch (_) {
      throw AiUnavailableException(
        'AI is temporarily unavailable. Try again in a moment.',
      );
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AiUnavailableException(_httpErrorMessage(resp));
    }

    final contentType = resp.headers['content-type'] ?? '';
    final raw = resp.body;
    if (contentType.contains('text/event-stream') ||
        raw.trimLeft().startsWith('data:')) {
      final fromSse = _parseSseContent(raw);
      if (fromSse.isNotEmpty) return fromSse;
    }
    if (raw.isEmpty) return const <String, dynamic>{};
    try {
      return jsonDecode(raw);
    } on FormatException {
      return raw;
    }
  }

  static String _httpErrorMessage(http.Response resp) {
    var errorMsg = 'AI temporarily unavailable.';
    try {
      final err = jsonDecode(resp.body);
      if (err is Map && err['error'] != null) {
        errorMsg = err['error'].toString();
      } else if (err is Map && err['message'] != null) {
        errorMsg = err['message'].toString();
      }
    } catch (_) {}
    return switch (resp.statusCode) {
      429 => 'Too many requests. Please wait a moment.',
      402 => 'AI credits exhausted. Please add funds.',
      413 => 'Message too long — start a new chat and try again.',
      401 => 'Please sign in again to use AI.',
      _ => errorMsg,
    };
  }

  static String _parseSseContent(String raw) {
    final buf = StringBuffer();
    for (var line in raw.split('\n')) {
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.startsWith(':') || line.trim().isEmpty) continue;
      if (!line.startsWith('data:')) continue;
      final jsonStr = line.substring(5).trim();
      if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
      try {
        final parsed = jsonDecode(jsonStr);
        final delta = _deltaFromChunk(parsed);
        if (delta != null && delta.isNotEmpty) buf.write(delta);
      } catch (_) {
        // Incomplete JSON chunk — skip.
      }
    }
    return buf.toString();
  }

  static String? _deltaFromChunk(dynamic parsed) {
    if (parsed is String) return parsed;
    if (parsed is! Map) return null;
    final map = Map<String, dynamic>.from(parsed);
    final choices = map['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final first = Map<String, dynamic>.from(choices.first as Map);
      final delta = first['delta'];
      if (delta is Map) {
        final content = delta['content']?.toString();
        if (content != null && content.isNotEmpty) return content;
      }
      final message = first['message'];
      if (message is Map) {
        final content = message['content']?.toString();
        if (content != null && content.isNotEmpty) return content;
      }
    }
    final nestedDelta = map['delta'];
    if (nestedDelta is Map) {
      final content = nestedDelta['content']?.toString();
      if (content != null && content.isNotEmpty) return content;
    }
    final content = map['content'];
    if (content is String && content.isNotEmpty) return content;
    final reply = map['reply']?.toString();
    if (reply != null && reply.trim().isNotEmpty) return reply.trim();
    return null;
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }

  static String? _parseEnhanceText(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty && !raw.trim().startsWith('{')) {
      return raw.trim();
    }
    final data = _asMap(raw);
    final out = data['text']?.toString().trim();
    if (out != null && out.isNotEmpty) return out;
    return _parseConciergeReply(raw);
  }

  static String? _parseConciergeReply(dynamic raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      if (!trimmed.startsWith('{') && !trimmed.startsWith('data:')) {
        return trimmed;
      }
      if (trimmed.startsWith('data:')) {
        final sse = _parseSseContent(raw);
        return sse.isEmpty ? null : sse;
      }
    }
    final data = _asMap(raw);
    final reply = data['reply']?.toString().trim();
    if (reply != null && reply.isNotEmpty) return reply;
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final message = first['message'];
        if (message is Map) {
          final content = message['content']?.toString().trim();
          if (content != null && content.isNotEmpty) return content;
        }
        final delta = first['delta'];
        if (delta is Map) {
          final content = delta['content']?.toString().trim();
          if (content != null && content.isNotEmpty) return content;
        }
      }
    }
    final text = data['text']?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
    return null;
  }

  static Map<String, dynamic> _jsonObjectFromText(String text) {
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) return const {};
    try {
      final decoded = jsonDecode(match.group(0)!);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  static String _normalizeReply(String text) {
    var cleaned = text
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\[truncated\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[continued\]', caseSensitive: false), '')
        .trim();
    return cleaned;
  }

  /// Cap `useConciergeAI` token loop. If a browser stream is interrupted or
  /// produces zero usable deltas, transparently retry the exact request through
  /// the reliable non-streaming path instead of surfacing a fake outage.
  Stream<String> chatConciergeTokens({
    required List<AiChatMessage> messages,
    String? character,
    Map<String, dynamic>? locationContext,
    String? preferredIntent,
  }) async* {
    final apiMessages = [
      for (final m in messages)
        if (m.content.trim().isNotEmpty)
          {'role': m.role, 'content': m.content.trim()},
    ];
    if (apiMessages.length > 12) {
      apiMessages.removeRange(0, apiMessages.length - 12);
    }
    final lastUser = messages.reversed
        .where((m) => m.role == 'user')
        .map((m) => m.content)
        .firstOrNull;
    final intent =
        preferredIntent ??
        (lastUser != null && _profileIntent.hasMatch(lastUser)
            ? 'profiles'
            : null);
    final payload = <String, dynamic>{
      'messages': apiMessages,
      'stream': true,
      if (character != null && character.isNotEmpty) 'character': character,
      if (locationContext != null && locationContext.isNotEmpty)
        'locationContext': locationContext,
      if (intent != null) 'preferredIntent': intent,
    };

    var yieldedAny = false;
    try {
      final url = Uri.parse(
        '${SupabaseService.supabaseUrl}/functions/v1/ai-concierge',
      );
      final token =
          _client.auth.currentSession?.accessToken ?? SupabaseService.anonKey;
      final request = http.Request('POST', url)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'apikey': SupabaseService.anonKey,
          'Accept': 'text/event-stream',
        })
        ..body = jsonEncode(payload);

      final resp = await _http.send(request).timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        final body = await resp.stream.bytesToString();
        throw AiUnavailableException(
          _httpErrorMessage(
            http.Response(body, resp.statusCode, headers: resp.headers),
          ),
        );
      }

      final contentType = resp.headers['content-type'] ?? '';
      var carry = '';
      await for (final chunk in resp.stream.transform(utf8.decoder)) {
        carry += chunk;
        if (contentType.contains('text/event-stream') ||
            carry.trimLeft().startsWith('data:')) {
          final parsed = _consumeSse(carry);
          carry = parsed.rest;
          if (parsed.delta.isNotEmpty) {
            yieldedAny = true;
            yield parsed.delta;
          }
        }
      }
      if (carry.trim().isNotEmpty) {
        if (carry.trimLeft().startsWith('data:')) {
          final parsed = _consumeSse('$carry\n');
          if (parsed.delta.isNotEmpty) {
            yieldedAny = true;
            yield parsed.delta;
          }
        } else {
          final reply = _parseConciergeReply(_tryJson(carry) ?? carry);
          if (reply != null && reply.isNotEmpty) {
            yieldedAny = true;
            yield reply;
          }
        }
      }
    } catch (_) {
      // Fall through to the non-streaming request below when nothing reached UI.
      if (yieldedAny) return;
    }

    if (!yieldedAny) {
      final fallback = await chatConcierge(
        messages: messages,
        character: character,
        locationContext: locationContext,
        preferredIntent: preferredIntent,
        stream: false,
      );
      if (fallback.trim().isNotEmpty) yield fallback;
    }
  }

  static ({String delta, String rest}) _consumeSse(String raw) {
    final buf = StringBuffer();
    final lines = raw.split('\n');
    final incomplete = !raw.endsWith('\n');
    final complete = incomplete ? lines.sublist(0, lines.length - 1) : lines;
    final rest = incomplete ? lines.last : '';
    for (var line in complete) {
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.startsWith(':') || line.trim().isEmpty) continue;
      if (!line.startsWith('data:')) continue;
      final jsonStr = line.substring(5).trim();
      if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;
      try {
        final parsed = jsonDecode(jsonStr);
        final delta = _deltaFromChunk(parsed);
        if (delta != null && delta.isNotEmpty) buf.write(delta);
      } catch (_) {
        // Keep incomplete JSON in rest by prepending — skip for now.
      }
    }
    return (delta: buf.toString(), rest: rest);
  }

  static dynamic _tryJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}

class AiChatMessage {
  const AiChatMessage({required this.role, required this.content});

  /// `user` | `assistant` | `system`
  final String role;
  final String content;
}

class AiUnavailableException implements Exception {
  AiUnavailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AiModerationException implements Exception {
  AiModerationException(this.message);
  final String message;

  @override
  String toString() => message;
}
