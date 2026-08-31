import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/chip_selector.dart';
import 'package:flutter_swipes/src/features/add/presentation/screens/add_listing_screen.dart';

/// Manual listing upload entry point (bottom dock + / profile empty-state add).
///
/// Header sparkles open the AI Listing Builder via [AppPaths.ownerListingsNew].
/// This chooser stays the plain form so users always have a non-AI path.
///
/// The manual form keeps one shared ListingDraft for the whole wizard, so a
/// value selected in one section is never requested again in another section.
/// Long chip groups are wrapped in an accordion scope to keep Details calm and
/// focused: one section opens at a time and closed sections retain a summary of
/// the user's selections.
Future<void> showCreateListingChooser(BuildContext context) async {
  AppHaptics.medium();
  await Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => const ChipSelectorAccordionScope(
        child: AddListingScreen(),
      ),
    ),
  );
}
