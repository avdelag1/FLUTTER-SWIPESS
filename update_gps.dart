import 'dart:io';

void main() {
  var file = File('lib/src/features/map/presentation/screens/web_discovery_map_screen_v8.dart');
  var content = file.readAsStringSync();

  if (!content.contains("import 'package:geolocator/geolocator.dart';")) {
    content = "import 'package:geolocator/geolocator.dart';\n" + content;
  }

  // 1. Add _findMyExactLocation inside _WebDiscoveryMapScreenV8State
  var method = '''
  Future<void> _findMyExactLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
    
    if (mounted) {
      ref.read(discoveryLocationProvider.notifier).setCoordinates(
        city: 'My Location',
        country: '',
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      // Also zoom in slightly closer for personal location
      ref.read(discoveryLocationProvider.notifier).setRadiusKm(10);
    }
  }
''';
  var targetStr = '  void _recenter(DiscoveryLocation loc) {';
  if (!content.contains('_findMyExactLocation()')) {
    content = content.replaceAll(targetStr, method + '\n' + targetStr);
  }

  // 2. Change the bottom-right button to use it instead of _recenter
  var btnStr = '''
            Positioned(
              right: 12,
              bottom: _trayHeight + pad.bottom + 18,
              child: _CircleAction(
                label: 'Recenter on \${loc.city}',
                icon: Icons.my_location_rounded,
                onTap: () => _recenter(loc),
              ),
            ),''';
  var newBtnStr = '''
            Positioned(
              right: 12,
              bottom: _trayHeight + pad.bottom + 18,
              child: _CircleAction(
                label: 'Find My Location',
                icon: Icons.my_location_rounded,
                onTap: _findMyExactLocation,
              ),
            ),''';
  content = content.replaceAll(btnStr, newBtnStr);

  // 3. Change the hamburger menu 'Recenter' to do it too
  var menuStr = "row(Icons.my_location_rounded, 'Recenter', onRecenter),";
  var newMenuStr = "row(Icons.my_location_rounded, 'My Exact Location', _findMyExactLocation),";
  content = content.replaceAll(menuStr, newMenuStr);
  
  // We need to pass _findMyExactLocation down to the _MapMenu
  // Look for _MapMenu constructor call
  var menuCallStr = '''
                    _MapMenu(
                      onCities: () {
                        setState(() {
                          _citiesOpen = true;
                          _menuOpen = false;
                        });
                      },
                      onRecenter: () {
                        _recenter(loc);
                        setState(() => _menuOpen = false);
                      },
                      onToggleTray: () {''';
                      
  var newMenuCallStr = '''
                    _MapMenu(
                      onCities: () {
                        setState(() {
                          _citiesOpen = true;
                          _menuOpen = false;
                        });
                      },
                      onRecenter: () {
                        _findMyExactLocation();
                        setState(() => _menuOpen = false);
                      },
                      onToggleTray: () {''';
  content = content.replaceAll(menuCallStr, newMenuCallStr);

  file.writeAsStringSync(content);
}
