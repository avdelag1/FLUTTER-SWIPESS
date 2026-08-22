import re

with open('lib/src/features/map/presentation/screens/real_mapbox_screen.dart', 'r') as f:
    text = f.read()

# Replace _cityLevelPoint signature and logic to use the item's own city instead of the view's loc.
old_func = """  ({double lat, double lng}) _cityLevelPoint(
    String key,
    DiscoveryLocation loc, {
    required bool listing,
  }) {
    var hash = listing ? 97 : 193;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    final angle = (hash % 360) * math.pi / 180;
    final ring = 0.008 + ((hash ~/ 360) % 7) * 0.0024;
    final lat = loc.latitude + math.sin(angle) * ring;
    final cosLat = math.cos(loc.latitude * math.pi / 180).abs();
    final lngScale = cosLat < .25 ? .25 : cosLat;
    final lng = loc.longitude + (math.cos(angle) * ring / lngScale);
    return (lat: lat, lng: lng);
  }"""

new_func = """  ({double lat, double lng}) _cityLevelPoint(
    dynamic item,
    DiscoveryLocation loc, {
    required bool listing,
  }) {
    final key = (item.id ?? '').toString();
    var hash = listing ? 97 : 193;
    for (final unit in key.codeUnits) {
      hash = 0x1fffffff & (hash * 31 + unit);
    }
    final angle = (hash % 360) * math.pi / 180;
    final ring = 0.008 + ((hash ~/ 360) % 7) * 0.0024;
    
    // Base the center on the item's actual city if possible, falling back to loc
    double centerLat = loc.latitude;
    double centerLng = loc.longitude;
    final itemCity = (item.city ?? '').toString().trim();
    if (itemCity.isNotEmpty) {
      final resolved = ListingLocations.resolve(itemCity);
      if (resolved != null) {
        centerLat = resolved.lat;
        centerLng = resolved.lng;
      }
    }
    
    final lat = centerLat + math.sin(angle) * ring;
    final cosLat = math.cos(centerLat * math.pi / 180).abs();
    final lngScale = cosLat < .25 ? .25 : cosLat;
    final lng = centerLng + (math.cos(angle) * ring / lngScale);
    return (lat: lat, lng: lng);
  }"""

text = text.replace(old_func, new_func)

# And fix the calls to it:
text = text.replace("_cityLevelPoint(listing.id, loc, listing: true);", "_cityLevelPoint(listing, loc, listing: true);")
text = text.replace("_cityLevelPoint(profile.id, loc, listing: false);", "_cityLevelPoint(profile, loc, listing: false);")

if 'import \'package:flutter_swipes/src/core/constants/listing_locations.dart\';' not in text:
    text = "import 'package:flutter_swipes/src/core/constants/listing_locations.dart';\n" + text

with open('lib/src/features/map/presentation/screens/real_mapbox_screen.dart', 'w') as f:
    f.write(text)
