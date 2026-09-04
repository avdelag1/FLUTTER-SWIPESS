import 'package:flutter_swipes/src/features/studio/domain/cinematic_template.dart';

enum _StudioStyle { glide, breathe, editorial, pulse, split }

class CinematicCatalog {
  const CinematicCatalog._();

  static List<CinematicTemplate> templatesFor(StudioCategory category) {
    final specs = _specs[category] ?? _specs[StudioCategory.property]!;
    return List<CinematicTemplate>.generate(
      specs.length,
      (index) {
        final spec = specs[index];
        return _template(
          id: '${category.name}_${spec.slug}',
          name: spec.name,
          category: category,
          description: spec.description,
          audioPresetId: spec.audioPresetId,
          style: spec.style,
        );
      },
      growable: false,
    );
  }

  static CinematicTemplate byId(String id) {
    for (final category in StudioCategory.values) {
      for (final template in templatesFor(category)) {
        if (template.id == id) return template;
      }
    }
    return templatesFor(StudioCategory.property).first;
  }

  static CinematicTemplate recommendedFor(String? listingCategory) =>
      templatesFor(studioCategoryFromName(listingCategory)).first;

  static CinematicTemplate _template({
    required String id,
    required String name,
    required StudioCategory category,
    required String description,
    required String audioPresetId,
    required _StudioStyle style,
  }) {
    final pattern = switch (style) {
      _StudioStyle.glide => const <CinematicShot>[
        CinematicShot(
          durationSeconds: 3.4,
          startScale: 1.06,
          endScale: 1.16,
          startPosition: StudioPoint(-.08, .01),
          endPosition: StudioPoint(.08, -.015),
          easing: StudioEasing.easeInOut,
          transition: StudioTransition.crossFade,
          transitionSeconds: .58,
        ),
        CinematicShot(
          durationSeconds: 3.2,
          startScale: 1.15,
          endScale: 1.05,
          startPosition: StudioPoint(.06, -.025),
          endPosition: StudioPoint(-.04, .02),
          easing: StudioEasing.easeInOut,
          transition: StudioTransition.pushLeft,
          transitionSeconds: .48,
        ),
        CinematicShot(
          durationSeconds: 3.5,
          startScale: 1.04,
          endScale: 1.13,
          startPosition: StudioPoint(0, .06),
          endPosition: StudioPoint(0, -.05),
          easing: StudioEasing.easeOut,
          transition: StudioTransition.crossFade,
          transitionSeconds: .6,
        ),
      ],
      _StudioStyle.breathe => const <CinematicShot>[
        CinematicShot(
          durationSeconds: 3.8,
          startScale: 1.045,
          endScale: 1.13,
          startPosition: StudioPoint(-.025, .02),
          endPosition: StudioPoint(.025, -.015),
          easing: StudioEasing.easeInOut,
          transition: StudioTransition.crossFade,
          transitionSeconds: .72,
        ),
        CinematicShot(
          durationSeconds: 3.8,
          startScale: 1.13,
          endScale: 1.045,
          startPosition: StudioPoint(.025, -.02),
          endPosition: StudioPoint(-.025, .015),
          easing: StudioEasing.easeInOut,
          transition: StudioTransition.crossFade,
          transitionSeconds: .72,
        ),
      ],
      _StudioStyle.editorial => const <CinematicShot>[
        CinematicShot(
          durationSeconds: 2.75,
          startScale: 1.02,
          endScale: 1.08,
          startPosition: StudioPoint(-.035, 0),
          endPosition: StudioPoint(.025, 0),
          easing: StudioEasing.easeOut,
          transition: StudioTransition.hardCut,
          transitionSeconds: .08,
        ),
        CinematicShot(
          durationSeconds: 3.0,
          startScale: 1.11,
          endScale: 1.045,
          startPosition: StudioPoint(.04, -.02),
          endPosition: StudioPoint(-.02, .025),
          easing: StudioEasing.easeInOut,
          transition: StudioTransition.crossFade,
          transitionSeconds: .34,
        ),
        CinematicShot(
          durationSeconds: 2.6,
          startScale: 1.04,
          endScale: 1.1,
          startPosition: StudioPoint(0, .04),
          endPosition: StudioPoint(0, -.035),
          easing: StudioEasing.easeOut,
          transition: StudioTransition.hardCut,
          transitionSeconds: .08,
        ),
      ],
      _StudioStyle.pulse => const <CinematicShot>[
        CinematicShot(
          durationSeconds: 1.7,
          startScale: 1.03,
          endScale: 1.18,
          startPosition: StudioPoint(-.05, 0),
          endPosition: StudioPoint(.03, -.01),
          easing: StudioEasing.easeOut,
          transition: StudioTransition.hardCut,
          transitionSeconds: .06,
        ),
        CinematicShot(
          durationSeconds: 1.55,
          startScale: 1.16,
          endScale: 1.04,
          startPosition: StudioPoint(.035, .015),
          endPosition: StudioPoint(-.035, -.02),
          easing: StudioEasing.easeOut,
          transition: StudioTransition.pushUp,
          transitionSeconds: .2,
        ),
        CinematicShot(
          durationSeconds: 1.8,
          startScale: 1.05,
          endScale: 1.15,
          startPosition: StudioPoint(0, .04),
          endPosition: StudioPoint(0, -.045),
          easing: StudioEasing.easeOut,
          transition: StudioTransition.hardCut,
          transitionSeconds: .06,
        ),
      ],
      _StudioStyle.split => const <CinematicShot>[
        CinematicShot(
          durationSeconds: 2.5,
          startScale: 1.045,
          endScale: 1.13,
          startPosition: StudioPoint(-.055, .01),
          endPosition: StudioPoint(.055, -.01),
          easing: StudioEasing.easeInOut,
          transition: StudioTransition.splitVertical,
          transitionSeconds: .48,
          cutAt: .5,
        ),
        CinematicShot(
          durationSeconds: 2.4,
          startScale: 1.12,
          endScale: 1.045,
          startPosition: StudioPoint(.04, -.035),
          endPosition: StudioPoint(-.04, .035),
          easing: StudioEasing.easeInOut,
          transition: StudioTransition.splitHorizontal,
          transitionSeconds: .45,
          cutAt: .5,
        ),
        CinematicShot(
          durationSeconds: 2.65,
          startScale: 1.04,
          endScale: 1.14,
          startPosition: StudioPoint(0, .045),
          endPosition: StudioPoint(0, -.04),
          easing: StudioEasing.easeOut,
          transition: StudioTransition.crossFade,
          transitionSeconds: .36,
        ),
      ],
    };

    return CinematicTemplate(
      id: id,
      version: 1,
      name: name,
      category: category,
      description: description,
      audioPresetId: audioPresetId,
      shotPattern: pattern,
    );
  }
}

class _TemplateSpec {
  const _TemplateSpec(
    this.slug,
    this.name,
    this.description,
    this.audioPresetId,
    this.style,
  );

  final String slug;
  final String name;
  final String description;
  final String audioPresetId;
  final _StudioStyle style;
}

const Map<StudioCategory, List<_TemplateSpec>> _specs =
    <StudioCategory, List<_TemplateSpec>>{
      StudioCategory.property: <_TemplateSpec>[
        _TemplateSpec(
          'estate_glide',
          'Estate Glide',
          'Slow luxury pans and elegant push transitions.',
          'luxury',
          _StudioStyle.glide,
        ),
        _TemplateSpec(
          'tropical_breathe',
          'Tropical Breathe',
          'Relaxed zoom in / zoom out movement for villas and stays.',
          'jungle',
          _StudioStyle.breathe,
        ),
        _TemplateSpec(
          'ocean_living',
          'Ocean Living',
          'Airy cinematic movement with long soft transitions.',
          'ocean',
          _StudioStyle.glide,
        ),
        _TemplateSpec(
          'architectural_cut',
          'Architectural Cut',
          'Clean editorial cuts that make details feel premium.',
          'clean_ambient',
          _StudioStyle.editorial,
        ),
        _TemplateSpec(
          'house_energy',
          'House Energy',
          'Fast punch zooms for modern, nightlife and investment listings.',
          'night_beach',
          _StudioStyle.pulse,
        ),
      ],
      StudioCategory.motorcycle: <_TemplateSpec>[
        _TemplateSpec(
          'street_rush',
          'Street Rush',
          'Punch zooms and fast cuts for speed and attitude.',
          'road',
          _StudioStyle.pulse,
        ),
        _TemplateSpec(
          'chrome_detail',
          'Chrome Detail',
          'Editorial movement for engine, wheels and finish.',
          'workshop',
          _StudioStyle.editorial,
        ),
        _TemplateSpec(
          'sunset_ride',
          'Sunset Ride',
          'Smooth left-right motion with a relaxed road feeling.',
          'chill',
          _StudioStyle.glide,
        ),
        _TemplateSpec(
          'garage_split',
          'Garage Split',
          'Split reveals and mechanical detail transitions.',
          'workshop',
          _StudioStyle.split,
        ),
        _TemplateSpec(
          'night_run',
          'Night Run',
          'Dark, energetic cuts for performance bikes.',
          'night_beach',
          _StudioStyle.pulse,
        ),
      ],
      StudioCategory.bicycle: <_TemplateSpec>[
        _TemplateSpec(
          'trail_flow',
          'Trail Flow',
          'Smooth movement for outdoor and adventure bikes.',
          'jungle',
          _StudioStyle.glide,
        ),
        _TemplateSpec(
          'city_spin',
          'City Spin',
          'Quick modern cuts for urban bikes and e-bikes.',
          'road',
          _StudioStyle.pulse,
        ),
        _TemplateSpec(
          'fresh_air',
          'Fresh Air',
          'Slow breathing zooms with an easy lifestyle pace.',
          'chill',
          _StudioStyle.breathe,
        ),
        _TemplateSpec(
          'detail_snap',
          'Detail Snap',
          'Sharp editorial presentation for components and condition.',
          'clean_ambient',
          _StudioStyle.editorial,
        ),
        _TemplateSpec(
          'frame_split',
          'Frame Split',
          'Graphic split transitions for colorful or custom builds.',
          'road',
          _StudioStyle.split,
        ),
      ],
      StudioCategory.worker: <_TemplateSpec>[
        _TemplateSpec(
          'human_story',
          'Human Story',
          'Warm slow movement that keeps the person at the center.',
          'chill',
          _StudioStyle.breathe,
        ),
        _TemplateSpec(
          'professional_clean',
          'Professional Clean',
          'Calm editorial presentation for serious services.',
          'clean_ambient',
          _StudioStyle.editorial,
        ),
        _TemplateSpec(
          'craft_detail',
          'Craft Detail',
          'Pan across tools, food, hands and finished work.',
          'workshop',
          _StudioStyle.glide,
        ),
        _TemplateSpec(
          'fast_results',
          'Fast Results',
          'Energetic before/after style cuts for active services.',
          'workshop',
          _StudioStyle.pulse,
        ),
        _TemplateSpec(
          'wellness_flow',
          'Wellness Flow',
          'Soft movement for massage, yoga, beauty and wellness.',
          'singing_bowl',
          _StudioStyle.breathe,
        ),
      ],
      StudioCategory.yacht: <_TemplateSpec>[
        _TemplateSpec(
          'ocean_drift',
          'Ocean Drift',
          'Long horizontal motion that feels like moving over water.',
          'ocean',
          _StudioStyle.glide,
        ),
        _TemplateSpec(
          'deck_luxury',
          'Deck Luxury',
          'Premium editorial pacing for cabins and details.',
          'luxury',
          _StudioStyle.editorial,
        ),
        _TemplateSpec(
          'sunset_sail',
          'Sunset Sail',
          'Slow breathing transitions for lifestyle imagery.',
          'chill',
          _StudioStyle.breathe,
        ),
        _TemplateSpec(
          'island_energy',
          'Island Energy',
          'Fast movement for parties, charters and adventure.',
          'night_beach',
          _StudioStyle.pulse,
        ),
        _TemplateSpec(
          'blue_split',
          'Blue Split',
          'Split reveals that contrast deck, ocean and interior.',
          'ocean',
          _StudioStyle.split,
        ),
      ],
      StudioCategory.jet: <_TemplateSpec>[
        _TemplateSpec(
          'executive_flight',
          'Executive Flight',
          'Slow luxury movement for aircraft and cabin photos.',
          'luxury',
          _StudioStyle.glide,
        ),
        _TemplateSpec(
          'runway_pulse',
          'Runway Pulse',
          'Fast punch cuts for takeoff energy and exterior shots.',
          'road',
          _StudioStyle.pulse,
        ),
        _TemplateSpec(
          'cloud_luxury',
          'Cloud Luxury',
          'Breathing zooms for soft premium travel imagery.',
          'clean_ambient',
          _StudioStyle.breathe,
        ),
        _TemplateSpec(
          'cabin_detail',
          'Cabin Detail',
          'Editorial cuts for seats, controls and amenities.',
          'luxury',
          _StudioStyle.editorial,
        ),
        _TemplateSpec(
          'night_departure',
          'Night Departure',
          'Graphic split transitions for dramatic runway imagery.',
          'night_beach',
          _StudioStyle.split,
        ),
      ],
    };
