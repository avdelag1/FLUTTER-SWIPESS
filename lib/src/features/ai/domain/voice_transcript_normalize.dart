/// Normalizes common speech-to-text mistakes for SWIPESS AI search.
String normalizeVoiceTranscript(String raw) {
  var text = raw;
  const replacements = <(String, String)>[
    ('context', 'contact'),
    ('contacts info', 'contact'),
    ('con tact', 'contact'),
    ('contact info', 'contact'),
    ('whats app', 'whatsapp'),
    ("what's app", 'whatsapp'),
    ('watsap', 'whatsapp'),
    ('watsapp', 'whatsapp'),
    ('phone number', 'phone'),
    ('numero de', 'numero'),
    ('número de', 'numero'),
    ('joyeria', 'jeweler'),
    ('joyería', 'jeweler'),
    ('plomero', 'plumber'),
    ('abogado', 'lawyer'),
    ('electricista', 'electrician'),
    ('mecanico', 'mechanic'),
    ('mecánico', 'mechanic'),
    ('busco a', 'find'),
    ('busco alguien', 'find someone'),
    ('necesito a', 'need'),
    ('necesito alguien', 'need someone'),
    ('quien es', 'who is'),
    ('quién es', 'who is'),
    ('se llama', 'named'),
    ('give me the number', 'phone number'),
    ('give me contact', 'contact'),
  ];
  for (final (from, to) in replacements) {
    text = text.replaceAll(RegExp(from, caseSensitive: false), to);
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Directory / trusted contact lookup — not page navigation.
final directoryContactIntent = RegExp(
  r'\b(people|person|persons|users|profiles|seekers|roommate|roommates|workers|professionals|friends|contacts?|someone|somebody|alguien|persona|personas|contacto|contactos|expert|experts|specialist|specialists|who can help|need help|looking for someone|find someone|need someone|who is|named|gente|jeweler|jewellery|jewelry|joyeria|joyería|plumber|plomero|electrician|electricista|mechanic|mecanico|mecánico|cleaner|limpieza|chef|driver|chauffeur|nanny|handyman|gardener|contractor|painter|carpenter|welder|technician|lawyer|abogado|attorney|doctor|dentist|stylist|barber|massage|masaje|hire|contratar|recommend|recomienda|recomendar|numero|número|whatsapp|phone|call|trusted|local help|directory|directorio|number for|contact for|info for)\b',
  caseSensitive: false,
);

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
  // Recognizer echo during segment restart can resend a shorter prefix.
  if (frozen.startsWith(next)) return false;
  
  // Sometimes the native recognizer re-evaluates the last word (e.g. "plummer" -> "plumber").
  // This causes the text to change slightly (and sometimes grow by 1-2 chars) without adding new words.
  // We only cancel the countdown if the user actually added more words.
  final nextWords = next.split(RegExp(r'\s+'));
  final frozenWords = frozen.split(RegExp(r'\s+'));
  return nextWords.length > frozenWords.length;
}
