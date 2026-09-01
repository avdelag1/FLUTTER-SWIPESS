import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/theme/nexus_theme.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/core/widgets/liquid_glass.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/add_listing_screen.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Capacitor “AI LISTING BUILDER” — welcome → compose → processing.
class AiListingBuilderScreen extends ConsumerStatefulWidget {
  const AiListingBuilderScreen({super.key});

  @override
  ConsumerState<AiListingBuilderScreen> createState() =>
      _AiListingBuilderScreenState();
}

class _AiListingBuilderScreenState
    extends ConsumerState<AiListingBuilderScreen> {
  String _category = 'property';
  final _city = TextEditingController();
  final _description = TextEditingController();
  final _photos = <XFile>[];
  bool _busy = false;
  bool _enhancing = false;

  /// Cap wizard: welcome | compose | processing
  String _step = 'compose';
  bool _hydrated = false;
  final _voice = LiveVoiceInput.instance;
  bool _micActive = false;

  static const _welcomeKey = 'hasSeenListingWelcome';

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_welcomeKey) ?? false;
      if (!mounted) return;
      // Keep location intentionally empty. SWIPESS is global, so the listing
      // builder must never imply that the user's city is Tulum (or any other
      // market) before they explicitly provide a location.
      setState(() {
        _step = seen ? 'compose' : 'welcome';
        _hydrated = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _hydrated = true);
      }
    }
  }

  void _closeBuilder() {
    NavBack.popOrGo(context, fallbackPath: AppPaths.clientDashboard);
  }

  Future<void> _continueWelcome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_welcomeKey, true);
    } catch (_) {}
    AppHaptics.medium();
    setState(() => _step = 'compose');
  }

  @override
  void dispose() {
    _voice.cancel(owner: this);
    _city.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_micActive || _voice.isOwnedBy(this)) {
      await _voice.finish(owner: this);
      if (mounted) setState(() => _micActive = false);
      return;
    }

    AppHaptics.medium();
    setState(() => _micActive = true);

    final started = await _voice.start(
      owner: this,
      initialText: _description.text,
      onText: (text) {
        if (!mounted) return;
        _description.text = text;
        _description.selection = TextSelection.collapsed(
          offset: _description.text.length,
        );
      },
      // A pause is not an instruction to stop dictation on this screen. The
      // shared recognizer intentionally stays armed and restarts across native
      // and browser speech segments until the user taps the mic again.
      onSilence: () {
        if (!mounted) return;
        final shouldStayActive = _voice.isOwnedBy(this) && _voice.active;
        if (shouldStayActive && !_micActive) {
          setState(() => _micActive = true);
        }
      },
      onSpeechActivity: () {
        if (!mounted) return;
        if (!_micActive) setState(() => _micActive = true);
      },
      onListeningChanged: (_) {
        if (!mounted) return;
        // Browsers and mobile recognizers briefly report not-listening between
        // recognition segments. Reflect the logical Swipess session instead of
        // that transport boundary so the mic does not look disconnected.
        final shouldStayActive = _voice.isOwnedBy(this) && _voice.active;
        if (_micActive != shouldStayActive) {
          setState(() => _micActive = shouldStayActive);
        }
      },
      onError: (message) {
        if (!mounted) return;
        if (!_voice.isOwnedBy(this) || !_voice.active) {
          setState(() => _micActive = false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      listenMode: ListenMode.dictation,
      restartAfterSilence: true,
    );

    if (!started && mounted) {
      setState(() => _micActive = false);
    }
  }

  Future<void> _pickPhotos() async {
    final files = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (files.isEmpty) return;
    setState(() {
      _photos
        ..clear()
        ..addAll(files.take(30));
    });
  }

  Future<void> _enhance() async {
    if (_enhancing) return;
    AppHaptics.light();
    final raw = _description.text.trim();
    if (raw.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a short description first')),
      );
      return;
    }
    setState(() => _enhancing = true);
    try {
      final polished = await ref
          .read(aiEdgeRepositoryProvider)
          .enhanceText(text: raw, type: 'listing');
      if (!mounted) return;
      if (polished == null || polished.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not enhance — try again')),
        );
        return;
      }
      setState(() => _description.text = polished);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI enhance applied')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not enhance right now. Your description is still here. ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _enhancing = false);
    }
  }

  String _parsedText(Map<String, dynamic> parsed, String key) {
    final value = parsed[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  List<String> _parsedList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(RegExp(r'[,;\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  bool _parsedBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == 'yes' || normalized == '1';
  }

  String _parsedPrice(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    final raw = value.toString().trim();
    if (raw.isEmpty) return '';
    final match = RegExp(r'\d[\d,.]*').firstMatch(raw);
    return (match?.group(0) ?? raw).replaceAll(',', '');
  }

  Future<void> _create() async {
    if (_busy) return;

    // Freeze the final dictated words before handing the draft to AI. This also
    // prevents a still-live microphone session from fighting the next screen.
    if (_voice.isOwnedBy(this)) {
      await _voice.finish(owner: this);
    }
    if (!mounted) return;

    setState(() {
      _micActive = false;
      _busy = true;
      _step = 'processing';
    });
    AppHaptics.medium();

    try {
      final notifier = ref.read(addListingProvider.notifier);
      var cat = switch (_category) {
        'motorcycle' => ListingCategory.motorcycle,
        'bicycle' => ListingCategory.bicycle,
        'yacht' => ListingCategory.yacht,
        'worker' => ListingCategory.worker,
        _ => ListingCategory.property,
      };
      notifier.reset();
      notifier.setCategory(cat);

      final desc = _description.text.trim();
      // Do not silently inject the currently selected discovery market. If the
      // user leaves this empty, AI may still infer a city from their description.
      final city = _city.text.trim();

      Map<String, dynamic> parsed = const <String, dynamic>{};
      if (desc.isNotEmpty) {
        // The loading screen must never become a dead end. The dedicated
        // extractor normally responds in a few seconds; if transport/model
        // parsing ever stalls, continue with the user's original text/photos.
        try {
          parsed = await ref
              .read(aiEdgeRepositoryProvider)
              .extractListing(category: _category, prompt: desc, city: city)
              .timeout(
                const Duration(seconds: 18),
                onTimeout: () => const <String, dynamic>{},
              );
        } catch (error) {
          debugPrint('[AiListingBuilder] extractor fallback: $error');
          parsed = const <String, dynamic>{};
        }
      }

      final detected = _parsedText(parsed, 'category').toLowerCase();
      if (const {
        'property',
        'motorcycle',
        'bicycle',
        'yacht',
        'worker',
      }.contains(detected)) {
        _category = detected;
        cat = switch (detected) {
          'motorcycle' => ListingCategory.motorcycle,
          'bicycle' => ListingCategory.bicycle,
          'yacht' => ListingCategory.yacht,
          'worker' => ListingCategory.worker,
          _ => ListingCategory.property,
        };
        notifier.setCategory(cat);
      }

      final titleRaw = _parsedText(parsed, 'title');
      final aiDescription = _parsedText(parsed, 'description');
      final descOut = aiDescription.isNotEmpty ? aiDescription : desc;
      final aiCity = _parsedText(parsed, 'city');
      final cityOut = aiCity.isNotEmpty ? aiCity : city;
      final priceOut = _parsedPrice(parsed['price']);
      final amenities = <String>[
        ..._parsedList(parsed['amenities']),
        if (desc.toLowerCase().contains('wifi')) 'WiFi',
        if (desc.toLowerCase().contains('pool')) 'Private Pool',
        if (desc.toLowerCase().contains('ac') ||
            desc.toLowerCase().contains('air'))
          'AC',
      ];
      final adjectives = <String>[
        if (descOut.toLowerCase().contains('ocean') ||
            descOut.toLowerCase().contains('beach'))
          'Oceanfront',
        if (descOut.toLowerCase().contains('pool')) 'Pool',
        if (descOut.toLowerCase().contains('luxury') ||
            descOut.toLowerCase().contains('premium'))
          'Luxury',
        if (descOut.toLowerCase().contains('modern')) 'Modern',
      ];

      // Respect the destination category's media limit even if the AI changes
      // category after the user selected many property photos.
      final maxPhotos = ref.read(addListingProvider).maxPhotos;
      final safePhotos = _photos.take(maxPhotos).toList(growable: false);
      final parsedCountry = _parsedText(parsed, 'country');
      final parsedSkills = _parsedList(parsed['skills']);

      notifier.update(
        (d) => d.copyWith(
          city: cityOut,
          country: parsedCountry.isNotEmpty ? parsedCountry : d.country,
          description: descOut,
          title: titleRaw.isNotEmpty
              ? titleRaw
              : (descOut.isEmpty
                    ? d.title
                    : (descOut.length > 48
                          ? '${descOut.substring(0, 48)}…'
                          : descOut)),
          price: priceOut.isNotEmpty ? priceOut : d.price,
          photos: safePhotos,
          adjectives: adjectives.isEmpty ? d.adjectives : adjectives,
          amenities: amenities.isEmpty
              ? d.amenities
              : amenities.toSet().toList(),
          beds: _parsedText(parsed, 'beds').isNotEmpty
              ? _parsedText(parsed, 'beds')
              : d.beds,
          baths: _parsedText(parsed, 'baths').isNotEmpty
              ? _parsedText(parsed, 'baths')
              : d.baths,
          propertyType: _parsedText(parsed, 'property_type').isNotEmpty
              ? _parsedText(parsed, 'property_type')
              : d.propertyType,
          furnished: _parsedBool(parsed['furnished']) || d.furnished,
          petFriendly: _parsedBool(parsed['pet_friendly']) || d.petFriendly,
          brand: _parsedText(parsed, 'make').isNotEmpty
              ? _parsedText(parsed, 'make')
              : (_parsedText(parsed, 'brand').isNotEmpty
                    ? _parsedText(parsed, 'brand')
                    : d.brand),
          model: _parsedText(parsed, 'model').isNotEmpty
              ? _parsedText(parsed, 'model')
              : d.model,
          year: _parsedText(parsed, 'year').isNotEmpty
              ? _parsedText(parsed, 'year')
              : d.year,
          mileage: _parsedText(parsed, 'mileage').isNotEmpty
              ? _parsedText(parsed, 'mileage')
              : d.mileage,
          engineCc: _parsedText(parsed, 'engine_cc').isNotEmpty
              ? _parsedText(parsed, 'engine_cc')
              : d.engineCc,
          vehicleType: _parsedText(parsed, 'vehicle_type').isNotEmpty
              ? _parsedText(parsed, 'vehicle_type')
              : d.vehicleType,
          condition: _parsedText(parsed, 'condition').isNotEmpty
              ? _parsedText(parsed, 'condition')
              : d.condition,
          lengthM: _parsedText(parsed, 'length_m').isNotEmpty
              ? _parsedText(parsed, 'length_m')
              : d.lengthM,
          berths: _parsedText(parsed, 'berths').isNotEmpty
              ? _parsedText(parsed, 'berths')
              : d.berths,
          maxPassengers: _parsedText(parsed, 'max_passengers').isNotEmpty
              ? _parsedText(parsed, 'max_passengers')
              : d.maxPassengers,
          serviceCategory: _parsedText(parsed, 'service_category').isNotEmpty
              ? _parsedText(parsed, 'service_category')
              : d.serviceCategory,
          pricingUnit: _parsedText(parsed, 'pricing_unit').isNotEmpty
              ? _parsedText(parsed, 'pricing_unit')
              : d.pricingUnit,
          skills: parsedSkills.isNotEmpty ? parsedSkills : d.skills,
        ),
      );

      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AddListingScreen(initialCategory: _category),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[AiListingBuilder] create handoff failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = 'compose';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not finish the AI setup. Your photos and description are still here — tap Continue to retry.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hydrated) {
      return const Scaffold(
        backgroundColor: Color(0xFF09090B),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFA5B4FC)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    NexusTheme.cyan.withAlpha(40),
                    NexusTheme.indigo.withAlpha(20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [NexusTheme.violet.withAlpha(40), Colors.transparent],
                ),
              ),
            ),
          ),
          if (_step == 'welcome')
            _ListingWelcome(
              onContinue: _continueWelcome,
              onSkip: _closeBuilder,
            )
          else if (_step == 'processing')
            const _ListingProcessing()
          else
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 88,
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: _buildCompose(),
            ),
        ],
      ),
    );
  }

  Widget _buildCompose() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: LiquidGlassPanel(
            borderRadius: 22,
            blur: LiquidGlass.blurSm,
            weight: LiquidGlassWeight.thin,
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        NexusTheme.indigo.withAlpha(50),
                        NexusTheme.violet.withAlpha(50),
                      ],
                    ),
                    border: Border.all(color: NexusTheme.violet.withAlpha(100)),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFA5B4FC),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) => NexusTheme.ai.createShader(b),
                        child: Text(
                          'AI LISTING BUILDER',
                          style: AppTheme.displayItalic.copyWith(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        'ONE-STEP AI SETUP',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFA5B4FC),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _closeBuilder,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              LiquidGlassPanel(
                borderRadius: 24,
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Upload photos and describe what you are offering. We\'ll generate a beautiful listing automatically.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('1. CATEGORY', style: _label),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (final c in const [
                      ('property', 'PROPERTY'),
                      ('motorcycle', 'MOTORCYCLE'),
                      ('bicycle', 'BICYCLE'),
                      ('yacht', 'YACHT'),
                      ('worker', 'JOB / SERVICE'),
                    ]) ...[
                      _CatChip(
                        label: c.$2,
                        selected: _category == c.$1,
                        onTap: () {
                          AppHaptics.selection();
                          setState(() => _category = c.$1);
                        },
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text('2. PHOTOS (${_photos.length}/30)', style: _label),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickPhotos,
                child: LiquidGlassPanel(
                  borderRadius: 28,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withAlpha(20),
                          ),
                          child: const Icon(
                            Icons.add_a_photo_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'UPLOAD RAW MEDIA',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'AI will analyze and arrange them automatically',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text('3. LOCATION', style: _label),
              const SizedBox(height: 10),
              GlassTextField(
                controller: _city,
                hint: '',
                icon: Icons.search_rounded,
              ),
              const SizedBox(height: 6),
              Text(
                'GENERAL AREA ONLY — NO EXACT ADDRESS',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text('4. DESCRIPTION', style: _label),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _toggleMic,
                    icon: Icon(
                      _micActive ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _micActive
                          ? const Color(0xFFFF4D6D)
                          : Colors.white60,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _enhancing ? null : _enhance,
                    icon: _enhancing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFC9B6FF),
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: Color(0xFFC9B6FF),
                          ),
                    label: Text(
                      'AI ENHANCE',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFC9B6FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              GlassTextField(
                controller: _description,
                hint:
                    "Describe your listing. E.g. 'Stunning ocean view villa with private pool, 2 bedrooms'...",
                icon: Icons.notes_rounded,
                maxLines: 5,
                height: 140,
              ),
              const SizedBox(height: 16),
              Text(
                'SECURELY PROCESSED BY GOOGLE GEMINI.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: NexusTheme.ai,
                    boxShadow: [
                      BoxShadow(
                        color: NexusTheme.indigo.withAlpha(80),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: _busy ? null : _create,
                      child: Center(
                        child: Text(
                          _busy ? 'PREPARING…' : 'CONTINUE TO LISTING',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle get _label => GoogleFonts.plusJakartaSans(
    color: const Color(0xFFA5B4FC),
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 2,
  );
}

class _ListingWelcome extends StatelessWidget {
  const _ListingWelcome({required this.onContinue, required this.onSkip});
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: NexusTheme.ai,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AI LISTING BUILDER',
              textAlign: TextAlign.center,
              style: AppTheme.displayItalic.copyWith(fontSize: 26),
            ),
            const SizedBox(height: 12),
            Text(
              'Snap a photo, say a sentence — and our AI will craft a stunning listing that sells in seconds.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 56,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: NexusTheme.ai,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onContinue,
                    child: Center(
                      child: Text(
                        'CONTINUE',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: onSkip,
              child: Text(
                'SKIP FOR NOW',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingProcessing extends StatelessWidget {
  const _ListingProcessing();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LiquidGlassPanel(
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(36, 40, 36, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFFA5B4FC),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'CRAFTING YOUR LISTING',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withAlpha(20),
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.white.withAlpha(80),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            color: selected ? const Color(0xFF0A0A0D) : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
