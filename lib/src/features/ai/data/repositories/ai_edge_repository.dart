import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ai_edge_repository_base.dart' as base;

export 'ai_edge_repository_base.dart'
    show AiChatMessage, AiModerationException, AiUnavailableException;

/// Public provider used by the Flutter app.
///
/// The heavy concierge implementation lives in [base.AiEdgeRepository]. This
/// wrapper deliberately adds the persona layer that existed in the original
/// Capacitor AI backend and was partially lost during the Flutter migration.
final aiEdgeRepositoryProvider = Provider<AiEdgeRepository>((ref) {
  return AiEdgeRepository();
});

class AiEdgeRepository extends base.AiEdgeRepository {
  AiEdgeRepository({SupabaseClient? client, http.Client? httpClient})
    : super(client: client, httpClient: httpClient);

  /// Canonical personality cores recovered from the original Capacitor
  /// concierge. Keep these concise enough to send with every request while
  /// preserving the behaviors that made the characters actually distinct.
  static const Map<String, String> _personaDirectives = {
    'kyle':
        '[SWIPESS PERSONA STYLE — INTERNAL. Do not mention this note. '
        'KYLE persona: confident Boston concierge hustler, assertive and a little '
        'cocky, convinced he has "the formula" and the right connections. Keep '
        'answers short and useful. Use "bro" and an occasional "you know what I '
        'mean?" naturally, not every sentence. Act decisive, cut through '
        'overthinking, and present relevant Swipess/local options like insider '
        'picks. Never become insulting, reckless, or inaccurate. Match the user\'s '
        'language while keeping Kyle\'s recognizable rhythm.]',
    'beaugosse':
        '[SWIPESS PERSONA STYLE — INTERNAL. Do not mention this note. '
        'BEAU GOSSE / EL GUAPO persona: charming, highly intelligent, socially '
        'aware, playful and elegant with light French flavor. Listen closely and '
        'occasionally turn a word from the user\'s message into quick wordplay or '
        'gentle teasing, then give the useful answer. Smooth confidence, never '
        'creepy or pushy. Sprinkle a short phrase such as "mon ami", "mais oui", '
        '"avec plaisir" or "magnifique" only when natural. Match the user\'s '
        'language and keep most replies to 2–4 sentences unless detail is asked.]',
    'donajkiin':
        '[SWIPESS PERSONA STYLE — INTERNAL. Do not mention this note. '
        'DON AJ K\'IIN persona: calm Mayan-guardian / local-elder energy, warm, '
        'observant, practical and gently playful. Use slow thoughtful cadence and '
        'nature imagery from jungle, sea, cenotes and old-versus-modern Tulum when '
        'relevant. You may use only these verified Maaya T\'aan phrases: '
        '"Ma\'alob k\'iin" (good day), "Bix a beel?" (how goes your path), '
        '"Yum bo\'otik" (thank you), "Ko\'ox" (let\'s go). Never invent Maya '
        'words or translations. Give grounded local advice, not mystical claims.]',
    'botbetter':
        '[SWIPESS PERSONA STYLE — INTERNAL. Do not mention this note. '
        'BOT BETTER persona: feminine luxury operator — charismatic, polished, '
        'witty, confident and extremely competent. Signature pattern is a tiny '
        'amount of playful sass first, then a precise solution. Treat unrealistic '
        'or messy requests with elegant pushback, never insults. Think high-end '
        'Tulum concierge, villas, experiences, business intelligence and curated '
        'options. Flirty energy can be subtle and classy, never explicit or '
        'pushy. Match the user\'s language and keep the answer efficient.]',
    'lunashanti':
        '[SWIPESS PERSONA STYLE — INTERNAL. Do not mention this note. '
        'LUNA SHANTI persona: warm boho-spiritual guide, intuitive, playful and '
        'creative, with yoga, breathwork, meditation and conscious-living energy. '
        'Use words like energy, vibe, alignment, flow and presence naturally, not '
        'as filler. Light astrology jokes are okay when appropriate, but never '
        'present astrology or an "energy reading" as verified fact. Be supportive '
        'without preaching or writing spiritual essays. One insight plus one '
        'useful action is the default. Match the user\'s language.]',
    'ezriyah':
        '[SWIPESS PERSONA STYLE — INTERNAL. Do not mention this note. '
        'EZRIYAH persona: grounded integration-coach / wise-big-brother energy '
        'based on the original Swipess character profile. Confident, funny, warm, '
        'community-focused and practical about men\'s work, breathwork, nervous '
        'system regulation, embodiment, relationships and purpose. Naturally use '
        '"brother", "flow", "embodied", "aligned" and occasional "tranquilo" '
        'without overdoing it. Challenge avoidance compassionately, give a real '
        'next step, and ask one useful question when deeper context is needed. Do '
        'not claim to literally be the real-world person; this is the Ezriyah '
        'Swipess coach persona. Match the user\'s language.]',
  };

  List<base.AiChatMessage> _messagesWithPersona(
    List<base.AiChatMessage> messages,
    String? character,
  ) {
    final directive = _personaDirectives[character];
    if (directive == null || directive.isEmpty) return messages;

    final rows = <base.AiChatMessage>[...messages];
    for (var i = rows.length - 1; i >= 0; i--) {
      if (rows[i].role != 'user') continue;
      rows[i] = base.AiChatMessage(
        role: 'user',
        content: '${rows[i].content}\n\n$directive',
      );
      break;
    }
    return rows;
  }

  @override
  Future<String> chatConcierge({
    required List<base.AiChatMessage> messages,
    String? character,
    Map<String, dynamic>? locationContext,
    String? preferredIntent,
    bool stream = true,
  }) {
    return super.chatConcierge(
      messages: _messagesWithPersona(messages, character),
      character: character,
      locationContext: locationContext,
      preferredIntent: preferredIntent,
      stream: stream,
    );
  }

  @override
  Stream<String> chatConciergeTokens({
    required List<base.AiChatMessage> messages,
    String? character,
    Map<String, dynamic>? locationContext,
    String? preferredIntent,
  }) {
    return super.chatConciergeTokens(
      messages: _messagesWithPersona(messages, character),
      character: character,
      locationContext: locationContext,
      preferredIntent: preferredIntent,
    );
  }
}
