/// Repairs a very small set of obvious speech-to-text mistakes for SWIPESS.
///
/// IMPORTANT: this function is intentionally conservative. The transcript is
/// the user's message, so do not translate, paraphrase, generalize, or replace
/// semantic words here. Proper names, mixed Spanish/English, local slang, and
/// phrases such as "wise man" or "shaman" must reach the AI exactly as spoken.
String normalizeVoiceTranscript(String raw) {
  var text = raw;
  const replacements = <(String, String)>[
    ('con tact', 'contact'),
    ('whats app', 'whatsapp'),
    ("what's app", 'whatsapp'),
    ('watsap', 'whatsapp'),
    ('watsapp', 'whatsapp'),
    ('tuum', 'tulum'),
    ('tuluum', 'tulum'),
    ('tulun', 'tulum'),
  ];
  for (final (from, to) in replacements) {
    text = text.replaceAll(RegExp(from, caseSensitive: false), to);
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Directory / trusted contact lookup — not page navigation.
final directoryContactIntent = RegExp(
  r'\b(people|person|persons|users|profiles|seekers|roommate|roommates|workers|professionals|friends|contacts?|someone|somebody|alguien|persona|personas|contacto|contactos|expert|experts|specialist|specialists|who can help|need help|looking for someone|find someone|need someone|who is|named|gente|girl|girls|guy|guys|woman|women|man|men|male|female|boy|boys|lady|ladies|dude|dudes|mamacita|canadian|canada|mexican|mexico|jeweler|jewellery|jewelry|joyeria|joyería|plumber|plomero|electrician|electricista|mechanic|mecanico|mecánico|cleaner|limpieza|chef|driver|chauffeur|nanny|handyman|gardener|contractor|painter|carpenter|welder|technician|lawyer|abogado|attorney|doctor|dentist|stylist|barber|massage|masaje|hire|contratar|recommend|recomienda|recomendar|numero|número|whatsapp|phone|call|trusted|local help|directory|directorio|number for|contact for|info for|rockstar|rock star|best model|jewelry maker|handmade jewelry|helpful man|helpful guy|vip|wise man|wise woman|shaman)\b',
  caseSensitive: false,
);

/// Demographic / trait descriptors — "canadian girl", "fitness coach", etc.
final personDescriptorIntent = RegExp(
  r'\b(girl|girls|guy|guys|woman|women|man|men|male|female|boy|boys|lady|ladies|dude|dudes|mamacita|canadian|canada|mexican|mexico|american|british|australian|spanish|french|italian|colombian|brazilian|argentinian|fitness|coach|poet|wise|gorgeous|beautiful|handsome|connector|wellness|yoga|pilates|shaman|guru|healer|mentor|spiritual|guide|curandero|curandera|medicine)\b',
  caseSensitive: false,
);

/// Specific person lookup — return one best match, not a 3-card batch.
bool isSpecificPersonSearch(String raw) {
  final q = normalizeVoiceTranscript(raw).toLowerCase();
  if (q.isEmpty) return false;
  if (RegExp(r'\b(who is|named|called)\b', caseSensitive: false).hasMatch(q)) {
    return true;
  }
  if (personDescriptorIntent.hasMatch(q)) return true;
  if (RegExp(
    r'\b(plumber|plomero|electrician|electricista|mechanic|mecanico|mecánico|lawyer|abogado|jeweler|joyero|joyeria|joyería|doctor|dentist|cleaner|chef|driver|handyman|gardener|contractor|stylist|barber|massage|masaje)\b',
    caseSensitive: false,
  ).hasMatch(q)) {
    return false;
  }
  return false;
}

/// Broad discovery — batch up to 3 results (people, properties, etc.).
bool isGeneralDiscoveryBrowse(String raw) {
  final q = normalizeVoiceTranscript(raw).toLowerCase();
  if (q.isEmpty) return false;
  if (isSpecificPersonSearch(raw)) return false;
  return RegExp(
    r'\b(find|show|give|get|list|search|browse)\s+(me\s+)?(people|persons|contacts?|properties|listings|homes|houses|events|workers|services|yachts|bikes|motorcycles)\b',
    caseSensitive: false,
  ).hasMatch(q);
}

/// User explicitly asked to leave the dashboard for another section.
bool wantsExplicitNavigation(String raw) {
  final q = normalizeVoiceTranscript(raw).toLowerCase();
  if (q.isEmpty) return false;

  final navVerb = RegExp(
    r'\b(open|go to|take me to|show me the|navigate to|bring me to|switch to|jump to|ir a|abre|abrir|ll[eé]vame a|mu[eé]strame la|ve a la|go to the)\b',
    caseSensitive: false,
  );
  if (!navVerb.hasMatch(q)) return false;

  return RegExp(
    r'\b(events?|party|seekers?|people page|map|messages?|inbox|legal|documents?|properties?|listings?|yachts?|motorcycles?|motos?|bikes?|bicycles?|workers?|services?|deck|swipe)\b',
    caseSensitive: false,
  ).hasMatch(q);
}

/// Returns true when [incoming] contains genuinely new words beyond [locked].
///
/// Used by the dashboard voice countdown so native recognizer restarts and
/// microphone-level spikes cannot cancel **3 → 2 → 1** unless the user is
/// actually adding new speech.
bool shouldCancelVoiceCountdownForText({
  required String incoming,
  required String locked,
}) {
  final next = normalizeVoiceTranscript(incoming.trim());
  final frozen = normalizeVoiceTranscript(locked.trim());
  if (next.isEmpty) return false;
  if (frozen.isEmpty) return true;
  if (next == frozen) return false;
  if (next.startsWith(frozen)) {
    return next.substring(frozen.length).trim().isNotEmpty;
  }
  if (frozen.startsWith(next)) return false;

  // Sometimes the native recognizer re-evaluates the last word (e.g. "plummer" -> "plumber").
  // This causes the text to change slightly (and sometimes grow by 1-2 chars) without adding new words.
  // We only cancel the countdown if the user actually added more words.
  final nextWords = next.split(RegExp(r'\s+'));
  final frozenWords = frozen.split(RegExp(r'\s+'));
  return nextWords.length > frozenWords.length;
}
