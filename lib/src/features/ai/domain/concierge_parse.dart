import 'dart:convert';

/// Cap `conciergeUtils.parseNavActions` — Intel Core tagged payloads.
class ConciergeParse {
  ConciergeParse._({
    required this.cleanContent,
    required this.navPaths,
    required this.listings,
    required this.profiles,
    required this.events,
    this.passportCity,
    this.filterAction,
    this.passportAction,
  });

  final String cleanContent;
  final List<String> navPaths;
  final List<Map<String, dynamic>> listings;
  final List<Map<String, dynamic>> profiles;
  final List<Map<String, dynamic>> events;
  final String? passportCity;
  final Map<String, dynamic>? filterAction;
  final Map<String, dynamic>? passportAction;

  static final _nav = RegExp(r'\[NAV:(/[^\]]+)\]');
  static final _listings = RegExp(r'\[LISTINGS:(\[[\s\S]*?\])\]');
  static final _profiles = RegExp(r'\[PROFILES:(\[[\s\S]*?\])\]');
  static final _events = RegExp(r'\[EVENTS:(\[[\s\S]*?\])\]');
  static final _passport = RegExp(r'\[PASSPORT:(\{[\s\S]*?\})\]');
  static final _draft = RegExp(r'\[DRAFT:[^:]+:(\{[\s\S]*?\})\]');
  static final _filter = RegExp(r'\[FILTER:(\{[\s\S]*?\})\]');

  static const navLabels = <String, String>{
    '/client/filters': 'Open Filters',
    '/client/profile': 'My Profile',
    '/client/settings': 'Settings',
    '/subscription/packages': 'View Packages',
    '/client/liked': 'Liked Listings',
    '/owner/listings': 'My Listings',
    '/owner/properties': 'My Listings',
    '/legal': 'Legal Section',
    '/explore/events': 'Browse Events',
    '/client/dashboard': 'Swipe Deck',
    '/map': 'Open Map',
    '/explore/seekers': 'Open Seekers',
  };

  static ConciergeParse of(String content) {
    final navPaths = <String>[];
    var listings = <Map<String, dynamic>>[];
    var profiles = <Map<String, dynamic>>[];
    var events = <Map<String, dynamic>>[];
    String? passportCity;
    Map<String, dynamic>? filterAction;
    Map<String, dynamic>? passportAction;

    var clean = content.replaceAllMapped(_nav, (m) {
      navPaths.add(m.group(1)!);
      return '';
    });
    clean = clean.replaceAllMapped(_listings, (m) {
      listings = _jsonList(m.group(1)!);
      return '';
    });
    clean = clean.replaceAllMapped(_profiles, (m) {
      profiles = _jsonList(m.group(1)!);
      return '';
    });
    clean = clean.replaceAllMapped(_events, (m) {
      events = _jsonList(m.group(1)!);
      return '';
    });
    clean = clean.replaceAllMapped(_passport, (m) {
      try {
        final map = jsonDecode(m.group(1)!) as Map<String, dynamic>;
        passportAction = map;
        passportCity = (map['city'] ?? map['passportLabel'] ?? map['label'])
            ?.toString();
      } catch (_) {}
      return '';
    });
    clean = clean.replaceAllMapped(_filter, (m) {
      try {
        filterAction = jsonDecode(m.group(1)!) as Map<String, dynamic>;
        final city = filterAction?['passportCity']?.toString();
        if (city != null && city.isNotEmpty) passportCity ??= city;
      } catch (_) {}
      return '';
    });
    clean = clean.replaceAll(_draft, '');

    final tags = [
      '[LISTINGS:',
      '[PROFILES:',
      '[EVENTS:',
      '[DRAFT:',
      '[FILTER:',
      '[PASSPORT:',
      '[NAV:',
    ];
    var earliest = -1;
    for (final tag in tags) {
      final idx = clean.indexOf(tag);
      if (idx != -1 && (earliest == -1 || idx < earliest)) earliest = idx;
    }
    if (earliest != -1) clean = clean.substring(0, earliest);
    clean = clean.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return ConciergeParse._(
      cleanContent: clean,
      navPaths: navPaths,
      listings: listings,
      profiles: profiles,
      events: events,
      passportCity: passportCity,
      filterAction: filterAction,
      passportAction: passportAction,
    );
  }

  static List<Map<String, dynamic>> _jsonList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return [
          for (final e in decoded)
            if (e is Map) Map<String, dynamic>.from(e),
        ];
      }
    } catch (_) {}
    return const [];
  }
}
