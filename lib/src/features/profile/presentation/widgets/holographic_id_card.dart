import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/documents/domain/legal_document.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/domain/vap_card_themes.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/themed_vap_card.dart';

/// Backward-compatible profile entry point for the VAP card.
///
/// The profile used to render a separate animated/holographic imitation here.
/// Keep the old widget name so callers do not break, but render the exact same
/// VAP card component used by the full VAP screen. This intentionally has no
/// shimmer, tilt, glow sweep, or fake "preview" treatment.
class HolographicIDCard extends StatelessWidget {
  const HolographicIDCard({
    super.key,
    required this.name,
    required this.idNumber,
    this.avatarUrl,
    required this.occupation,
    required this.location,
    required this.years,
    required this.bio,
  });

  final String name;
  final String idNumber;
  final String? avatarUrl;
  final String occupation;
  final String location;

  /// Kept for compatibility with the existing Profile call site. The value
  /// currently comes from the profile's age field, so map it to AGE rather
  /// than incorrectly presenting it as "LOCAL SINCE".
  final String years;
  final String bio;

  @override
  Widget build(BuildContext context) {
    final rawId = idNumber.startsWith('NX-') ? idNumber.substring(3) : idNumber;
    final data = VapIdCard(
      userId: rawId,
      name: name,
      avatarUrl: avatarUrl,
      occupation: occupation,
      city: location,
      age: int.tryParse(years),
      yearsInCity: null,
      bio: bio,
    );

    return SizedBox(
      height: 620,
      child: ThemedVapCard(
        theme: VapCardTheme.themes.first,
        data: data,
        idNumber: idNumber,
        validationUrl: 'https://swipess.com/vap-validate/$rawId',
        docsAsync: const AsyncData<List<LegalDocument>>(<LegalDocument>[]),
        // The whole profile card opens the full VAP screen. Document actions
        // remain on the full card so this embedded card cannot feel like a
        // second mini-preview/navigation layer.
        onPreview: (_) {},
      ),
    );
  }
}
