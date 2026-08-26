import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/add_listing_screen.dart';

/// One-tap create entry point.
///
/// The old chooser added an unnecessary modal before the actual listing form.
/// The dashboard/profile + button now opens the real upload flow immediately;
/// category and listing mode are selected inside the form itself.
Future<void> showCreateListingChooser(BuildContext context) async {
  AppHaptics.medium();
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(builder: (_) => const AddListingScreen()),
  );
}
