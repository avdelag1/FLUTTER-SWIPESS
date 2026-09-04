import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/studio/data/cinematic_catalog.dart';
import 'package:flutter_swipes/src/features/studio/domain/cinematic_template.dart';

void main() {
  group('Swipess Studio cinematic catalog', () {
    test('ships five templates for every supported Studio category', () {
      for (final category in StudioCategory.values) {
        final templates = CinematicCatalog.templatesFor(category);
        expect(templates, hasLength(5), reason: category.name);
        expect(templates.map((e) => e.id).toSet(), hasLength(5));
        for (final template in templates) {
          expect(template.category, category);
          expect(template.version, greaterThan(0));
          expect(template.width, 1080);
          expect(template.height, 1920);
          expect(template.fps, 30);
          expect(template.shotPattern, isNotEmpty);
        }
      }
    });

    test('a 3-6 photo project always resolves to a valid deterministic frame', () {
      final template = CinematicCatalog.templatesFor(
        StudioCategory.property,
      ).first;

      for (var count = 3; count <= 6; count++) {
        final duration = template.totalDurationFor(count);
        expect(duration, greaterThan(0));
        expect(duration, lessThanOrEqualTo(30));

        for (final fraction in <double>[0, .25, .5, .75, .999]) {
          final frame = template.resolveAtSeconds(duration * fraction, count);
          expect(frame.imageIndex, inInclusiveRange(0, count - 1));
          expect(frame.nextImageIndex, inInclusiveRange(0, count - 1));
          expect(frame.shotProgress, inInclusiveRange(0, 1));
          expect(frame.transitionProgress, inInclusiveRange(0, 1));
          expect(frame.scale, inInclusiveRange(1, 1.3));
          expect(frame.x, inInclusiveRange(-.18, .18));
          expect(frame.y, inInclusiveRange(-.18, .18));
        }
      }
    });

    test('render JSON keeps focal points normalized and one shot per photo', () {
      final template = CinematicCatalog.templatesFor(
        StudioCategory.motorcycle,
      ).last;
      final json = template.toRenderJson(
        photoCount: 4,
        focalPoints: const <int, StudioFocalPoint>{
          0: StudioFocalPoint(x: -.2, y: 1.5),
          2: StudioFocalPoint(x: .8, y: .1),
        },
      );

      expect(json['fps'], 30);
      expect(json['width'], 1080);
      expect(json['height'], 1920);
      final shots = json['shots'] as List<Map<String, dynamic>>;
      expect(shots, hasLength(4));
      expect((shots[0]['focal'] as Map)['x'], 0.0);
      expect((shots[0]['focal'] as Map)['y'], 1.0);
      expect((shots[2]['focal'] as Map)['x'], .8);
      expect((shots[2]['focal'] as Map)['y'], .1);
    });

    test('category aliases map into the right Studio family', () {
      expect(studioCategoryFromName('property'), StudioCategory.property);
      expect(studioCategoryFromName('moto'), StudioCategory.motorcycle);
      expect(studioCategoryFromName('bike'), StudioCategory.bicycle);
      expect(studioCategoryFromName('job'), StudioCategory.worker);
      expect(studioCategoryFromName('people'), StudioCategory.worker);
      expect(studioCategoryFromName('boat'), StudioCategory.yacht);
      expect(studioCategoryFromName('jets'), StudioCategory.jet);
    });
  });
}
