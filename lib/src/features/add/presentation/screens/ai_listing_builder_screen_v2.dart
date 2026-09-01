import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/add/domain/listing_draft.dart';
import 'package:flutter_swipes/src/features/add/presentation/providers/add_listing_provider.dart';
import 'package:flutter_swipes/src/features/ai/data/repositories/ai_edge_repository.dart';
import 'package:flutter_swipes/src/features/ai/presentation/services/live_voice_input.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Direct AI listing flow:
/// photos -> continuous dictation -> Create Listing -> publish.
///
/// There is deliberately no intermediate "Crafting your listing" route/state.
/// The user stays on this screen while AI extracts structured fields and the
/// existing listing publisher uploads the media. If something required is
/// missing, the screen stays editable and explains exactly what is needed.
class AiListingBuilderScreen extends ConsumerStatefulWidget {
  const AiListingBuilderScreen({super.key});

  @override
  ConsumerState<AiListingBuilderScreen> createState() =>
      _AiListingBuilderScreenState();
}

class _AiListingBuilderScreenState
    extends ConsumerState<AiListingBuilderScreen> {
  static const _pink = Color(0xFFFF2D6F);
  static const _panel = Color(0xFF151519);
  static const _border = Color(0xFF303038);

  final _city = TextEditingController();
  final _description = TextEditingController();
  final _photos = <XFile>[];
  final _voice = LiveVoiceInput.instance;

  String _category = 'property';
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
          // Silence is only a pause. Dictation remains armed until the user
          // explicitly taps the microphone again.
          if (!mounted || !_micWanted) return;
          if (!_micActive) setState(() => _micActive = true);
        },
        onSpeechActivity: () {
          if (!mounted || !_micWanted) return;
          if (!_micActive) setState(() => _micActive = true);
        },
        onListeningChanged: (_) {
          if (!mounted) return;
          // Native/browser recognizers naturally cycle between segments. The
          // visible microphone represents user intent, not that transport state.
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

    // Temporary network/recognizer errors must not silently turn dictation off.
    // Reconnect while the user still wants the microphone armed.
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
    final remaining = 30 - _photos.length;
    if (remaining <= 0) {
      _showMessage('Maximum 30 photos reached.');
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
        _showMessage('Could not enhance right now. Your description is still here.');
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
        _showMessage('Could not enhance right now. Your description is still here.');
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

  String _priceFromDescription(String text) {
    final prefixed = RegExp(
      r'(?:\$\s*|\b(?:usd|mxn|price)\s*[:=]?\s*)(\d[\d,]*(?:\.\d+)?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (prefixed != null) {
      return (prefixed.group(1) ?? '').replaceAll(',', '');
    }
    final suffixed = RegExp(
      r'(\d[\d,]*(?:\.\d+)?)\s*(?:usd|mxn|dollars?|pesos?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    return (suffixed?.group(1) ?? '').replaceAll(',', '');
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

  ListingMode _modeFrom(Map<String, dynamic> parsed, String description) {
    final raw = '${_parsedText(parsed, 'mode')} ${_parsedText(parsed, 'listing_type')}'
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

  Future<void> _create() async {
    if (_busy) return;
    if (_photos.isEmpty) {
      _showMessage('Add at least one photo first.');
      return;
    }
    if (_description.text.trim().length < 3) {
      _showMessage('Describe what you are listing first.');
      return;
    }

    await _stopMic();
    if (!mounted) return;

    setState(() {
      _busy = true;
      _status = 'Reading your description…';
    });
    AppHaptics.medium();

    final notifier = ref.read(addListingProvider.notifier);
    try {
      final originalDescription = _description.text.trim();
      final typedCity = _city.text.trim();

      var parsed = const <String, dynamic>{};
      try {
        parsed = await ref
            .read(aiEdgeRepositoryProvider)
            .extractListing(
              category: _category,
              prompt: originalDescription,
              city: typedCity,
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
      final description = aiDescription.isNotEmpty
          ? aiDescription
          : originalDescription;
      final aiCity = _parsedText(parsed, 'city');
      final city = aiCity.isNotEmpty ? aiCity : typedCity;
      var price = _parsedPrice(parsed['price']);
      if (price.isEmpty) price = _priceFromDescription(originalDescription);
      final title = _parsedText(parsed, 'title');
      final country = _parsedText(parsed, 'country');
      final amenities = <String>[
        ..._parsedList(parsed['amenities']),
        if (originalDescription.toLowerCase().contains('wifi')) 'WiFi',
        if (originalDescription.toLowerCase().contains('pool')) 'Private Pool',
        if (originalDescription.toLowerCase().contains('air conditioning') ||
            originalDescription.toLowerCase().contains(' a/c') ||
            originalDescription.toLowerCase().contains(' ac '))
          'AC',
      ].toSet().toList();
      final skills = _parsedList(parsed['skills']);

      final maxPhotos = ref.read(addListingProvider).maxPhotos;
      final safePhotos = _photos.take(maxPhotos).toList(growable: false);

      notifier.update(
        (draft) => draft.copyWith(
          city: city,
          country: country.isNotEmpty ? country : draft.country,
          description: description,
          title: title.isNotEmpty ? title : draft.title,
          price: price,
          photos: safePhotos,
          amenities: amenities.isNotEmpty ? amenities : draft.amenities,
          beds: _parsedText(parsed, 'beds').isNotEmpty
              ? _parsedText(parsed, 'beds')
              : draft.beds,
          baths: _parsedText(parsed, 'baths').isNotEmpty
              ? _parsedText(parsed, 'baths')
              : draft.baths,
          propertyType: _parsedText(parsed, 'property_type').isNotEmpty
              ? _parsedText(parsed, 'property_type')
              : draft.propertyType,
          furnished: _parsedBool(parsed['furnished']) || draft.furnished,
          petFriendly:
              _parsedBool(parsed['pet_friendly']) || draft.petFriendly,
          brand: _parsedText(parsed, 'make').isNotEmpty
              ? _parsedText(parsed, 'make')
              : (_parsedText(parsed, 'brand').isNotEmpty
                    ? _parsedText(parsed, 'brand')
                    : draft.brand),
          model: _parsedText(parsed, 'model').isNotEmpty
              ? _parsedText(parsed, 'model')
              : draft.model,
          year: _parsedText(parsed, 'year').isNotEmpty
              ? _parsedText(parsed, 'year')
              : draft.year,
          mileage: _parsedText(parsed, 'mileage').isNotEmpty
              ? _parsedText(parsed, 'mileage')
              : draft.mileage,
          engineCc: _parsedText(parsed, 'engine_cc').isNotEmpty
              ? _parsedText(parsed, 'engine_cc')
              : draft.engineCc,
          vehicleType: _parsedText(parsed, 'vehicle_type').isNotEmpty
              ? _parsedText(parsed, 'vehicle_type')
              : draft.vehicleType,
          condition: _parsedText(parsed, 'condition').isNotEmpty
              ? _parsedText(parsed, 'condition')
              : draft.condition,
          lengthM: _parsedText(parsed, 'length_m').isNotEmpty
              ? _parsedText(parsed, 'length_m')
              : draft.lengthM,
          berths: _parsedText(parsed, 'berths').isNotEmpty
              ? _parsedText(parsed, 'berths')
              : draft.berths,
          maxPassengers: _parsedText(parsed, 'max_passengers').isNotEmpty
              ? _parsedText(parsed, 'max_passengers')
              : draft.maxPassengers,
          serviceCategory: _parsedText(parsed, 'service_category').isNotEmpty
              ? _parsedText(parsed, 'service_category')
              : draft.serviceCategory,
          pricingUnit: _parsedText(parsed, 'pricing_unit').isNotEmpty
              ? _parsedText(parsed, 'pricing_unit')
              : draft.pricingUnit,
          skills: skills.isNotEmpty ? skills : draft.skills,
        ),
      );

      final prepared = ref.read(addListingProvider);
      if (prepared.city.trim().isEmpty) {
        setState(() {
          _busy = false;
          _status = null;
        });
        _showMessage(
          'I need the city before publishing. Type it in Location and tap Create Listing again.',
        );
        return;
      }
      final parsedPrice = double.tryParse(prepared.price.trim());
      if (parsedPrice == null || parsedPrice <= 0) {
        setState(() {
          _busy = false;
          _status = null;
        });
        _showMessage(
          'I need the price before publishing. Say or type it in the description, for example: “\$2,500 per month.”',
        );
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

  String _friendlyPublishError(String? error) {
    final message = error?.trim() ?? '';
    if (message.isEmpty) {
      return 'Could not publish this listing. Please try again.';
    }
    final lower = message.toLowerCase();
    if (lower.contains('at least 1 photo')) return 'Add at least one photo first.';
    if (lower.contains('price greater than 0')) {
      return 'Add a valid price and try again.';
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
                    'Add photos, describe it by voice, then publish.',
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
                      _categoryChip('property', 'Property', Icons.home_rounded),
                      _categoryChip('worker', 'Worker', Icons.handyman_rounded),
                      _categoryChip(
                        'motorcycle',
                        'Motorcycle',
                        Icons.two_wheeler_rounded,
                      ),
                      _categoryChip('bicycle', 'Bicycle', Icons.pedal_bike_rounded),
                      _categoryChip('yacht', 'Yacht', Icons.sailing_rounded),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('LOCATION'),
                  const SizedBox(height: 8),
                  _inputShell(
                    child: TextField(
                      controller: _city,
                      enabled: !_busy,
                      style: _fieldTextStyle,
                      decoration: _inputDecoration(
                        hint: 'City, e.g. Tulum',
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('PHOTOS')),
                      Text(
                        '${_photos.length}/30',
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
                            : () => setState(() => _photos.removeAt(index)),
                      ),
                    ),
                    const SizedBox(height: 9),
                    _addPhotosButton(large: false),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _sectionTitle('DESCRIBE IT')),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _micWanted
                              ? _pink.withValues(alpha: .16)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _micWanted ? _pink : _border,
                          ),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _micWanted ? _pink : _border,
                        width: _micWanted ? 1.4 : 1,
                      ),
                    ),
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
                                'Say everything naturally — price, bedrooms, bathrooms, location, amenities, details…',
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
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  onPressed: (_busy || _enhancing || _micWanted)
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
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 54,
                                height: 54,
                                child: FilledButton(
                                  onPressed: _busy ? null : _toggleMic,
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        _micWanted ? _pink : Colors.white,
                                    foregroundColor:
                                        _micWanted ? Colors.white : Colors.black,
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                  ),
                                  child: _micConnecting && _micWanted
                                      ? const SizedBox(
                                          width: 19,
                                          height: 19,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.3,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          _micActive
                                              ? Icons.stop_rounded
                                              : Icons.mic_rounded,
                                          size: 25,
                                        ),
                                ),
                              ),
                            ],
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
                        border: Border.all(color: _border),
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
                        disabledBackgroundColor: _pink.withValues(alpha: .42),
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
                    'Create Listing publishes directly. There is no extra crafting or editor step.',
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
      onSelected: _busy ? null : (_) => setState(() => _category = value),
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
      backgroundColor: _panel,
      side: BorderSide(color: selected ? _pink : _border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }

  Widget _inputShell({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
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
        prefixIcon: Icon(icon, color: const Color(0xFFB9B9C2), size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
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
            color: _panel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_photo_alternate_rounded, color: _pink),
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
              return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
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
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
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
