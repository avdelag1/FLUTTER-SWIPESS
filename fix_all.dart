import 'dart:io';

void main() {
  // 1. Fix Geolocator accuracy
  var mapFile = File('lib/src/features/map/presentation/screens/web_discovery_map_screen_v8.dart');
  var mapContent = mapFile.readAsStringSync();
  mapContent = mapContent.replaceAll(
    'final position = await Geolocator.getCurrentPosition(\n      desiredAccuracy: LocationAccuracy.medium,\n    );',
    'final position = await Geolocator.getCurrentPosition(\n      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),\n    );'
  );
  mapContent = mapContent.replaceAll(
    'desiredAccuracy: LocationAccuracy.medium',
    'locationSettings: const LocationSettings(accuracy: LocationAccuracy.best)'
  );
  mapFile.writeAsStringSync(mapContent);

  // 2. Fix package names
  var iapFile = File('lib/src/features/payments/domain/iap_catalog.dart');
  if (iapFile.existsSync()) {
    var iapContent = iapFile.readAsStringSync();
    iapContent = iapContent.replaceAll("'Semi-Annual'", "'6 Months'");
    iapContent = iapContent.replaceAll("'SEMI-ANNUAL'", "'6 MONTHS'");
    iapContent = iapContent.replaceAll("'Yearly'", "'1 Year Unlimited'");
    iapContent = iapContent.replaceAll("'YEARLY'", "'1 YEAR UNLIMITED'");
    iapFile.writeAsStringSync(iapContent);
  }

  var pkgFile = File('lib/src/features/subscriptions/presentation/screens/subscription_packages_screen_v3.dart');
  if (pkgFile.existsSync()) {
    var pkgContent = pkgFile.readAsStringSync();
    pkgContent = pkgContent.replaceAll("'SEMI-ANNUAL'", "'6 MONTHS'");
    pkgContent = pkgContent.replaceAll("'Semi-Annual'", "'6 Months'");
    pkgContent = pkgContent.replaceAll("'YEARLY'", "'1 YEAR UNLIMITED'");
    pkgContent = pkgContent.replaceAll("'Yearly Pro'", "'1 Year Unlimited'");
    pkgContent = pkgContent.replaceAll("'YEARLY PRO'", "'1 YEAR UNLIMITED'");
    pkgFile.writeAsStringSync(pkgContent);
  }

  // 3. Remove NeoNaiveScaffold frame
  var scaffoldFile = File('lib/src/core/widgets/ambient_page_background.dart');
  if (scaffoldFile.existsSync()) {
    var scaffoldContent = scaffoldFile.readAsStringSync();
    // NeoNaiveScaffold wraps the body in a glass container with a border.
    // We will change it to just render the body directly with black background.
    var neoStr = '''
class NeoNaiveScaffold extends StatelessWidget {
  NeoNaiveScaffold({super.key, required this.body, this.floatingActionButton});

  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: floatingActionButton,
      body: AmbientPageBackground(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF16161C).withAlpha(245),
                  border: Border(
                    top: BorderSide(color: Colors.white.withAlpha(50), width: 1.5),
                    left: BorderSide(color: Colors.white.withAlpha(50), width: 1.5),
                    right: BorderSide(color: Colors.white.withAlpha(50), width: 1.5),
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: body,
              ),
            ),
          ),
        ),
      ),
    );
  }
}''';
    var newNeoStr = '''
class NeoNaiveScaffold extends StatelessWidget {
  const NeoNaiveScaffold({super.key, required this.body, this.floatingActionButton});

  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}''';
    scaffoldContent = scaffoldContent.replaceAll(neoStr, newNeoStr);
    
    // Fallback if the string wasn't exactly that (due to missing const or different formatting)
    if (scaffoldContent.contains('padding: const EdgeInsets.fromLTRB(12, 12, 12, 0)')) {
       scaffoldContent = scaffoldContent.replaceAll(
         'padding: const EdgeInsets.fromLTRB(12, 12, 12, 0)',
         'padding: EdgeInsets.zero'
       );
       scaffoldContent = scaffoldContent.replaceAll(
         'BorderSide(color: Colors.white.withAlpha(50), width: 1.5)',
         'BorderSide.none'
       );
       scaffoldContent = scaffoldContent.replaceAll(
         'borderRadius: const BorderRadius.vertical(top: Radius.circular(32))',
         'borderRadius: BorderRadius.zero'
       );
    }
    
    scaffoldFile.writeAsStringSync(scaffoldContent);
  }
  
  // 4. Fix free trial logic (make trial grant Premium access)
  var trialFile = File('lib/src/features/subscriptions/domain/subscription_tier.dart');
  if (trialFile.existsSync()) {
    var trialContent = trialFile.readAsStringSync();
    // In subscription_tier.dart, we might just want to check if they have trial active.
    // But SubscriptionTier is an enum.
    // Let's modify SubscriptionRepository to return Premium if trial is active.
  }
}
