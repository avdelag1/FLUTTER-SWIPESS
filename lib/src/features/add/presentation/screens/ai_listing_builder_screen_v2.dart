import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Direct AI listing flow:
/// photos + required basics -> continuous dictation -> AI filter extraction
/// -> Create Listing -> publish.
///
/// The user stays on this screen while AI turns the natural-language
/// description into the category-specific listing filters.
class AiListingBuilderScreen extends ConsumerStatefulWidget {
  const AiListingBuilderScreen({super.key});

  @override
  ConsumerState<AiListingBuilderScreen> createState() =>
      _AiListingBuilderScreenState();
}

class _AiListingBuilderScreenState
    extends ConsumerState<AiListingBuilderScreen> {
  static const _pink = Color(0xFFFF2D6F);
  static const _panel = Color(0xFF17171C);
  static const _panelRaised = Color(0xFF212128);
  static const _blue = Color(0xFF4DA3FF);

  final _city = TextEditingController();
  final _price = TextEditingController();
  final _description = TextEditingController();
  final _photos = <XFile>[];
  final _voice = LiveVoiceInput.instance;

  String _category = 'property';
  String _currency = 'USD';
  bool _busy = false;
  bool _enhancing = false;
  bool _micWanted = false;
  bool _micActive = false;
  bool _micConnecting = false;
  String? _status;
  Timer? _micRestartTimer;

  @override
  void dispose() {
    _micRestartTimer?.cancel();
    _voice.cancel(owner: this);
    _city.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  void _closeBuilder() {
    NavBack.popOrGo(context, fallbackPath: AppPaths.clientDashboard);
  }

  Future<void> _toggleMic() async {
    if (_micWanted) {
      await _stopMic();
      return;
    }
    setState(() {
      _micWanted = true;
      _micActive = true;
    });
    AppHaptics.medium();
    await _startDictationSession();
  }

  Future<void> _startDictationSession() async {
    if (!mounted || !_micWanted || _micConnecting) return;
    _micConnecting = true;
    try {
      final started = await _voice.start(
        owner: this,
        initialText: _description.text,
        onText: (text) {
          if (!mounted || !_micWanted) return;
          _description.text = text;
          _description.selection = TextSelection.collapsed(
            offset: _description.text.length,
          );
          if (!_micActive) setState(() => _micActive = true);
        },
        onSilence: () {
          if (!mounted || !_micWanted) return;
          if (!_micActive) setState(() => _micActive = true);
        },
        onSpeechActivity: () {
          if (!mounted || !_micWanted) return;
          if (!_micActive) setState(() => _micActive = true);
        },
        onListeningChanged: (_) {
          if (!mounted) return;
          if (_micWanted && !_micActive) setState(() => _micActive = true);
        },
        onError: _handleMicError,
        listenMode: ListenMode.dictation,
        restartAfterSilence: true,
      );
      if (!mounted) return;
      if (!started && _micWanted) {
        _scheduleMicRestart();
      }
    } finally {
      _micConnecting = false;
    }
  }

  void _handleMicError(String message) {
    if (!mounted || !_micWanted) return;
    final lower = message.toLowerCase();
    final permissionProblem = lower.contains('permission') ||
        lower.contains('allow microphone') ||
        lower.contains('not authorized');
    if (permissionProblem) {
      _micRestartTimer?.cancel();
      setState(() {
        _micWanted = false;
        _micActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    debugPrint('[AiListingBuilder] voice transport restart: $message');
    _scheduleMicRestart();
  }

  void _scheduleMicRestart() {
    _micRestartTimer?.cancel();
    _micRestartTimer = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted || !_micWanted) return;
      await _voice.cancel(owner: this);
      if (!mounted || !_micWanted) return;
      await _startDictationSession();
    });
  }

  Future<void> _stopMic() async {
    _micRestartTimer?.cancel();
    _micRestartTimer = null;
    if (mounted) {
      setState(() {
        _micWanted = false;
        _micActive = false;
      });
    }
    if (_voice.isOwnedBy(this)) {
      await _voice.finish(owner: this);
    }
  }

  Future<void> _pickPhotos() async {
    if (_busy) return;
    final maxForCategory = _photoLimitForCategory(_categoryEnum(_category));
    final remaining = maxForCategory - _photos.length;
    if (remaining <= 0) {
      _showMessage('Maximum $maxForCategory photos reached for this listing.');
      return;
    }

    final picker = ImagePicker();
    final List<XFile> picked;
    if (remaining == 1) {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2400,
        maxHeight: 2400,
        requestFullMetadata: false,
      );
      picked = file == null ? const <XFile>[] : <XFile>[file];
    } else {
      picked = await picker.pickMultiImage(
        limit: remaining,
        imageQuality: 92,
        maxWidth: 2400,
        maxHeight: 2400,
        requestFullMetadata: false,
      );
    }
    if (picked.isEmpty || !mounted) return;
    setState(() => _photos.addAll(picked.take(remaining)));
  }

  Future<void> _enhance() async {
    if (_enhancing || _busy) return;
    if (_micWanted) {
      _showMessage('Tap the microphone to finish dictation before enhancing.');
      return;
    }
    final raw = _description.text.trim();
    if (raw.length < 5) {
      _showMessage('Describe the listing first.');
      return;
    }

    setState(() => _enhancing = true);
    try {
      final polished = await ref
          .read(aiEdgeRepositoryProvider)
          .enhanceText(text: raw, type: 'listing')
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (polished == null || polished.trim().isEmpty) {
        _showMessage(
          'Could not enhance right now. Your description is still here.',
        );
        return;
      }
      setState(() {
        _description.text = polished.trim();
        _description.selection = TextSelection.collapsed(
          offset: _description.text.length,
        );
      });
    } catch (error) {
      debugPrint('[AiListingBuilder] enhance fallback: $error');
      if (mounted) {
        _showMessage(
          'Could not enhance right now. Your description is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _enhancing = false);
    }
  }

  String _parsedText(Map<String, dynamic> parsed, String key) {
    final value = parsed[key];
    if (value == null) return '';
    return value.toString().trim();
  }

  String _firstParsedText(
    Map<String, dynamic> parsed,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _parsedText(parsed, key);
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  List<String> _parsedList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where(
            (item) => item.isNotEmpty && item.toLowerCase() != 'null',
          )
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(RegExp(r'[,;\n]'))
          .map((item) => item.trim())
          .where(
            (item) => item.isNotEmpty && item.toLowerCase() != 'null',
          )
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

  ListingCategory _categoryEnum(String category) {
    return switch (category) {
      'motorcycle' => ListingCategory.motorcycle,
      'bicycle' => ListingCategory.bicycle,
      'yacht' => ListingCategory.yacht,
      'worker' => ListingCategory.worker,
      _ => ListingCategory.property,
    };
  }

  int _photoLimitForCategory(ListingCategory category) {
    switch (category) {
      case ListingCategory.property:
        return 30;
      case ListingCategory.yacht:
        return 12;
      case ListingCategory.worker:
        return 8;
      case ListingCategory.motorcycle:
      case ListingCategory.bicycle:
        return 5;
    }
  }

  ListingMode _modeFrom(Map<String, dynamic> parsed, String description) {
    final raw =
        '${_parsedText(parsed, 'mode')} ${_parsedText(parsed, 'listing_type')}'
            .toLowerCase();
    if (raw.contains('both')) return ListingMode.both;
    if (raw.contains('sale') || raw.contains('sell')) return ListingMode.sale;
    if (raw.contains('rent')) return ListingMode.rent;
    final text = description.toLowerCase();
    if (text.contains('for sale') || text.contains('selling')) {
      return ListingMode.sale;
    }
    return ListingMode.rent;
  }

  String _vehicleTypeFrom(Map<String, dynamic> parsed) {
    return _firstParsedText(
      parsed,
      const [
        'vehicle_type',
        'motorcycle_type',
        'bicycle_type',
        'yacht_type',
      ],
    );
  }

  String? _nullableText(String value, String? fallback) {
    return value.isEmpty ? fallback : value;
  }

  List<String> _useList(List<String> parsed, List<String> fallback) {
    return parsed.isEmpty ? fallback : parsed;
  }

  String? _pricingUnitFromParsed(String raw, String? fallback) {
    switch (raw.toLowerCase()) {
      case 'hour':
      case 'hourly':
        return 'Hourly';
      case 'day':
      case 'daily':
        return 'Daily';
      case 'job':
      case 'project':
      case 'per-job':
        return 'Per-job';
      case 'month':
      case 'monthly':
      case 'monthly contract':
        return 'Monthly contract';
      case 'week':
      case 'weekly':
        return 'Weekly';
      default:
        return raw.isEmpty ? fallback : raw;
    }
  }

  Future<void> _create() async {
    if (_busy) return;
    if (_photos.isEmpty) {
      _showMessage('Add at least one photo first.');
      return;
    }

    final typedCity = _city.text.trim();
    if (typedCity.isEmpty) {
      _showMessage('Add the city first.');
      return;
    }

    final typedPrice = _parsedPrice(_price.text);
    final parsedTypedPrice = double.tryParse(typedPrice);
    if (parsedTypedPrice == null || parsedTypedPrice <= 0) {
      _showMessage('Add a valid price greater than 0.');
      return;
    }

    final originalDescription = _description.text.trim();
    if (originalDescription.length < 3) {
      _showMessage('Describe what you are listing first.');
      return;
    }

    await _stopMic();
    if (!mounted) return;

    setState(() {
      _busy = true;
      _status = 'AI is filling the listing details…';
    });
    AppHaptics.medium();

    final notifier = ref.read(addListingProvider.notifier);
    final verificationDocuments =
        List<XFile>.of(ref.read(addListingProvider).legalDocuments);
    try {
      var parsed = const <String, dynamic>{};
      try {
        final structuredPrompt = '''
Currency: $_currency
City: $typedCity
Description:
$originalDescription
''';
        parsed = await ref
            .read(aiEdgeRepositoryProvider)
            .extractListing(
              category: _category,
              prompt: structuredPrompt,
              city: typedCity,
              price: typedPrice,
            )
            .timeout(
              const Duration(seconds: 8),
              onTimeout: () => const <String, dynamic>{},
            );
      } catch (error) {
        debugPrint('[AiListingBuilder] extractor fallback: $error');
      }
      if (!mounted) return;

      final detected = _parsedText(parsed, 'category').toLowerCase();
      if (const {
        'property',
        'motorcycle',
        'bicycle',
        'yacht',
        'worker',
      }.contains(detected)) {
        _category = detected;
      }

      final category = _categoryEnum(_category);
      notifier.reset();
      notifier.setCategory(category);
      notifier.setMode(_modeFrom(parsed, originalDescription));

      final aiDescription = _parsedText(parsed, 'description');
      final description =
          aiDescription.isNotEmpty ? aiDescription : originalDescription;
      final country = _parsedText(parsed, 'country');
      final title = _parsedText(parsed, 'title');
      final neighborhood = _parsedText(parsed, 'neighborhood');
      final vehicleType = _vehicleTypeFrom(parsed);

      final amenities = <String>[
        ..._parsedList(parsed['amenities']),
        if (originalDescription.toLowerCase().contains('wifi')) 'WiFi',
        if (originalDescription.toLowerCase().contains('pool')) 'Private Pool',
        if (originalDescription.toLowerCase().contains('air conditioning') ||
            originalDescription.toLowerCase().contains(' a/c') ||
            originalDescription.toLowerCase().contains(' ac '))
          'AC',
      ].toSet().toList();

      final maxPhotos = ref.read(addListingProvider).maxPhotos;
      final safePhotos = _photos.take(maxPhotos).toList(growable: false);

      notifier.update(
        (draft) => draft.copyWith(
          city: typedCity,
          country: country.isNotEmpty ? country : draft.country,
          neighborhood: neighborhood.isNotEmpty
              ? neighborhood
              : draft.neighborhood,
          description: description,
          title: title.isNotEmpty ? title : draft.title,
          price: typedPrice,
          currency: _currency,
          photos: safePhotos,
          legalDocuments: verificationDocuments,
          adjectives: _useList(
            _parsedList(parsed['adjectives']),
            draft.adjectives,
          ),
          sizes: _useList(_parsedList(parsed['sizes']), draft.sizes),
          propertyType: _nullableText(
            _parsedText(parsed, 'property_type'),
            draft.propertyType,
          ),
          beds: _nullableText(_parsedText(parsed, 'beds'), draft.beds),
          baths: _nullableText(_parsedText(parsed, 'baths'), draft.baths),
          vibe: _useList(_parsedList(parsed['vibe']), draft.vibe),
          amenities: amenities.isNotEmpty ? amenities : draft.amenities,
          included: _useList(
            _parsedList(parsed['included']),
            draft.included,
          ),
          rules: _useList(_parsedList(parsed['rules']), draft.rules),
          furnished: _parsedBool(parsed['furnished']) || draft.furnished,
          petFriendly:
              _parsedBool(parsed['pet_friendly']) || draft.petFriendly,
          rentalDuration: _nullableText(
            _firstParsedText(
              parsed,
              const ['rental_duration', 'rental_duration_type'],
            ),
            draft.rentalDuration,
          ),
          brand: _nullableText(
            _firstParsedText(parsed, const ['make', 'brand']),
            draft.brand,
          ),
          model: _nullableText(_parsedText(parsed, 'model'), draft.model),
          year: _parsedText(parsed, 'year').isNotEmpty
              ? _parsedText(parsed, 'year')
              : draft.year,
          mileage: _parsedText(parsed, 'mileage').isNotEmpty
              ? _parsedText(parsed, 'mileage')
              : draft.mileage,
          engineCc: _parsedText(parsed, 'engine_cc').isNotEmpty
              ? _parsedText(parsed, 'engine_cc')
              : draft.engineCc,
          vehicleType: _nullableText(vehicleType, draft.vehicleType),
          condition: _nullableText(
            _parsedText(parsed, 'condition'),
            draft.condition,
          ),
          features: _useList(
            _parsedList(parsed['features']),
            draft.features,
          ),
          vehicleIncluded: _useList(
            _firstNonEmptyParsedList(
              parsed,
              const ['vehicle_included', 'included_vehicle'],
            ),
            draft.vehicleIncluded,
          ),
          frameSize: _nullableText(
            _parsedText(parsed, 'frame_size'),
            draft.frameSize,
          ),
          lengthM: _parsedText(parsed, 'length_m').isNotEmpty
              ? _parsedText(parsed, 'length_m')
              : draft.lengthM,
          berths: _parsedText(parsed, 'berths').isNotEmpty
              ? _parsedText(parsed, 'berths')
              : draft.berths,
          maxPassengers: _parsedText(parsed, 'max_passengers').isNotEmpty
              ? _parsedText(parsed, 'max_passengers')
              : draft.maxPassengers,
          serviceCategory: _nullableText(
            _parsedText(parsed, 'service_category'),
            draft.serviceCategory,
          ),
          traits: _useList(_parsedList(parsed['traits']), draft.traits),
          skills: _useList(_parsedList(parsed['skills']), draft.skills),
          availability: _useList(
            _parsedList(parsed['availability']),
            draft.availability,
          ),
          pricingUnit: _pricingUnitFromParsed(
            _parsedText(parsed, 'pricing_unit'),
            draft.pricingUnit,
          ),
          languages: _useList(
            _parsedList(parsed['languages']),
            draft.languages,
          ),
        ),
      );

      final prepared = ref.read(addListingProvider);
      final parsedPrice = double.tryParse(prepared.price.trim());
      if (prepared.city.trim().isEmpty ||
          parsedPrice == null ||
          parsedPrice <= 0) {
        setState(() {
          _busy = false;
          _status = null;
        });
        _showMessage('City and price are required before publishing.');
        return;
      }

      setState(() => _status = 'Uploading photos and publishing…');
      final published = await notifier.publish();
      if (!mounted) return;

      if (!published) {
        final error = ref.read(addListingProvider).error;
        setState(() {
          _busy = false;
          _status = null;
        });
        _showMessage(_friendlyPublishError(error));
        return;
      }

      setState(() => _status = 'Listing published ✓');
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) _closeBuilder();
    } catch (error, stackTrace) {
      debugPrint('[AiListingBuilder] direct publish failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
      });
      _showMessage(
        'Could not publish this listing right now. Your photos and description are still here — try again.',
      );
    }
  }

  List<String> _firstNonEmptyParsedList(
    Map<String, dynamic> parsed,
    List<String> keys,
  ) {
    for (final key in keys) {
      final values = _parsedList(parsed[key]);
      if (values.isNotEmpty) return values;
    }
    return const <String>[];
  }

  String _friendlyPublishError(String? error) {
    final message = error?.trim() ?? '';
    if (message.isEmpty) {
      return 'Could not publish this listing. Please try again.';
    }
    final lower = message.toLowerCase();
    if (lower.contains('at least 1 photo')) {
      return 'Add at least one photo first.';
    }
    if (lower.contains('price greater than 0')) {
      return 'Add a valid price and try again.';
    }
    if (lower.contains('choose usd or mxn')) {
      return 'Choose USD or MXN and try again.';
    }
    if (lower.contains('city is required')) {
      return 'Add the city and try again.';
    }
    if (lower.contains('session expired')) return message;
    if (lower.contains('postgres') ||
        lower.contains('postgrest') ||
        lower.contains('invalid input syntax') ||
        lower.contains('sqlstate')) {
      return 'The listing could not be saved. Please try again — your information is still here.';
    }
    return message.length > 180
        ? 'Could not publish this listing. Please try again.'
        : message;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final photoLimit = _photoLimitForCategory(_categoryEnum(_category));
    final verificationDraft = ref.watch(addListingProvider).copyWith(
      category: _categoryEnum(_category),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: _busy ? null : _closeBuilder),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'CREATE WITH AI',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Set the basics, add photos, describe it naturally, then publish.',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFB9B9C2),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('WHAT ARE YOU LISTING?'),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _categoryChip(
                        'property',
                        'Property',
                        Icons.home_rounded,
                      ),
                      _categoryChip(
                        'worker',
                        'Worker',
                        Icons.handyman_rounded,
                      ),
                      _categoryChip(
                        'motorcycle',
                        'Motorcycle',
                        Icons.two_wheeler_rounded,
                      ),
                      _categoryChip(
                        'bicycle',
                        'Bicycle',
                        Icons.pedal_bike_rounded,
                      ),
                      _categoryChip(
                        'yacht',
                        'Yacht',
                        Icons.sailing_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('BASICS'),
                  const SizedBox(height: 8),
                  _inputShell(
                    child: TextField(
                      controller: _city,
                      enabled: !_busy,
                      textInputAction: TextInputAction.next,
                      style: _fieldTextStyle,
                      decoration: _inputDecoration(
                        hint: 'City',
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _inputShell(
                          child: TextField(
                            controller: _price,
                            enabled: !_busy,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            style: _fieldTextStyle,
                            decoration: _inputDecoration(
                              hint: 'Price, e.g. 30000',
                              icon: Icons.payments_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      SizedBox(
                        width: 112,
                        child: _inputShell(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _currency,
                                isExpanded: true,
                                dropdownColor: _panel,
                                iconEnabledColor: Colors.white,
                                style: _fieldTextStyle,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'USD',
                                    child: Text('USD'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'MXN',
                                    child: Text('MXN'),
                                  ),
                                ],
                                onChanged: _busy
                                    ? null
                                    : (value) {
                                        if (value == null) return;
                                        setState(() => _currency = value);
                                      },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('PHOTOS')),
                      Text(
                        '${_photos.length}/$photoLimit',
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFF8F8F98),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_photos.isEmpty)
                    _addPhotosButton(large: true)
                  else ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _photos.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemBuilder: (context, index) => _PhotoTile(
                        file: _photos[index],
                        onRemove: _busy
                            ? null
                            : () =>
                                setState(() => _photos.removeAt(index)),
                      ),
                    ),
                    const SizedBox(height: 9),
                    _addPhotosButton(large: false),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('DESCRIBE IT')),
                      _micStatusChip(),
                      const SizedBox(width: 8),
                      _micButton(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF232329), Color(0xFF17171C)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .38),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    foregroundDecoration: _micWanted
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: _pink.withValues(alpha: .82),
                              width: 1.2,
                            ),
                          )
                        : null,
                    child: Column(
                      children: [
                        TextField(
                          controller: _description,
                          enabled: !_busy,
                          minLines: 6,
                          maxLines: 10,
                          style: _fieldTextStyle,
                          decoration: InputDecoration(
                            hintText:
                                'Describe it naturally — bedrooms, bathrooms, amenities, condition, style, included items, details…',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF777780),
                              fontSize: 13,
                              height: 1.35,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.fromLTRB(
                              16,
                              16,
                              16,
                              10,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed:
                                  (_busy || _enhancing || _micWanted)
                                      ? null
                                      : _enhance,
                              icon: _enhancing
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.auto_awesome_rounded),
                              label: const Text('Enhance'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_micWanted) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 4),
                        const _PulseDot(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Listening continuously — tap the microphone when you are finished.',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFD0D0D6),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  _verificationCard(verificationDraft),
                  const SizedBox(height: 20),
                  if (_status != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF17171D),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .26),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          if (_busy) ...[
                            const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: _pink,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              _status!,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _create,
                      style: FilledButton.styleFrom(
                        backgroundColor: _pink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            _pink.withValues(alpha: .42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(
                        _busy ? 'PUBLISHING…' : 'CREATE LISTING',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .35,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI uses your description to fill the listing details, then publishes directly.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF777780),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVerificationDocuments() async {
    if (_busy) return;
    await ref.read(addListingProvider.notifier).pickLegalDocuments();
    if (!mounted) return;
    final error = ref.read(addListingProvider).error;
    if (error != null && error.trim().isNotEmpty) _showMessage(error);
  }

  Future<void> _captureVerificationDocument() async {
    if (_busy) return;
    await ref.read(addListingProvider.notifier).captureLegalDocument();
    if (!mounted) return;
    final error = ref.read(addListingProvider).error;
    if (error != null && error.trim().isNotEmpty) _showMessage(error);
  }

  Widget _verificationCard(ListingDraft draft) {
    final documents = draft.legalDocuments;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17202B), Color(0xFF121419)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .36),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: _blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'GET THE BLUE CHECK',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .3,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .07),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'OPTIONAL',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFFAAAAB4),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      draft.verificationTitle,
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFE7E7EC),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Send ownership, authorization, registration or professional proof privately. Swipess admins review it; approved listings get the blue check.',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFFB9B9C2),
              fontSize: 11,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Useful proof: ${draft.verificationProofHint}',
            style: GoogleFonts.plusJakartaSans(
              color: _blue,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _pickVerificationDocuments,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue.withValues(alpha: .15),
                      foregroundColor: const Color(0xFF83C4FF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.upload_file_rounded, size: 19),
                    label: Text(
                      documents.isEmpty
                          ? 'ADD LEGAL DOCUMENTS'
                          : 'ADD MORE DOCUMENTS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .25,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              SizedBox(
                width: 44,
                height: 44,
                child: FilledButton(
                  onPressed: _busy ? null : _captureVerificationDocument,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: .07),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, size: 19),
                ),
              ),
            ],
          ),
          if (documents.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${documents.length} document${documents.length == 1 ? '' : 's'} ready for private review',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFE7E7EC),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            ...List.generate(documents.length, (index) {
              final file = documents[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(11, 8, 6, 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_rounded,
                      color: Color(0xFF83C4FF),
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: const Color(0xFFD7D7DE),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () => ref
                              .read(addListingProvider.notifier)
                              .removeLegalDocument(index),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: Color(0xFF9B9BA5),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 14,
                color: Color(0xFF8F8F98),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Private. Never shown on the public listing.',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8F8F98),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _micStatusChip() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _micWanted
            ? _pink.withValues(alpha: .16)
            : Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _micWanted ? 'MIC ON' : 'MIC OFF',
        style: GoogleFonts.plusJakartaSans(
          color: _micWanted ? _pink : const Color(0xFF8F8F98),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: .6,
        ),
      ),
    );
  }

  Widget _micButton() {
    return SizedBox(
      width: 42,
      height: 42,
      child: FilledButton(
        onPressed: _busy ? null : _toggleMic,
        style: FilledButton.styleFrom(
          backgroundColor: _micWanted ? _pink : Colors.white,
          foregroundColor: _micWanted ? Colors.white : Colors.black,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: _micConnecting && _micWanted
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Icon(
                _micActive ? Icons.stop_rounded : Icons.mic_rounded,
                size: 21,
              ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF9B9BA5),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      );

  Widget _categoryChip(String value, String label, IconData icon) {
    final selected = _category == value;
    return ChoiceChip(
      selected: selected,
      onSelected: _busy
          ? null
          : (_) {
              final newCategory = _categoryEnum(value);
              final max = _photoLimitForCategory(newCategory);
              setState(() {
                _category = value;
                if (_photos.length > max) {
                  _photos.removeRange(max, _photos.length);
                }
              });
            },
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? Colors.white : const Color(0xFFB9B9C2),
      ),
      label: Text(label),
      labelStyle: GoogleFonts.plusJakartaSans(
        color: selected ? Colors.white : const Color(0xFFD0D0D6),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
      selectedColor: _pink,
      backgroundColor: _panelRaised,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }

  Widget _inputShell({required Widget child}) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF25252B), Color(0xFF1A1A1F)],
          ),
          borderRadius: BorderRadius.circular(19),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .34),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(
          color: const Color(0xFF777780),
          fontSize: 13,
        ),
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFB9B9C2),
          size: 20,
        ),
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      );

  TextStyle get _fieldTextStyle => GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );

  Widget _addPhotosButton({required bool large}) => InkWell(
        onTap: _busy ? null : _pickPhotos,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: large ? 118 : 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF222228), Color(0xFF17171C)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .30),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_photo_alternate_rounded,
                  color: _pink,
                ),
                const SizedBox(width: 9),
                Text(
                  large ? 'ADD PHOTOS' : 'ADD MORE PHOTOS',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: Colors.white,
          ),
          const Spacer(),
          Text(
            'SWIPESS AI',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback? onRemove;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.file.readAsBytes();
  }

  @override
  void didUpdateWidget(covariant _PhotoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _bytes = widget.file.readAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<Uint8List>(
            future: _bytes,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null) {
                return const ColoredBox(
                  color: Color(0xFF1C1C22),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          ),
          if (widget.onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: widget.onRemove,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: const BoxDecoration(
                    color: Color(0xCC000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: .45,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const SizedBox(
        width: 8,
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _AiListingBuilderScreenState._pink,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
