from pathlib import Path
import re

DRAFT = Path('lib/src/features/add/domain/listing_draft.dart')
PROVIDER = Path('lib/src/features/add/presentation/providers/add_listing_provider.dart')
SCREEN = Path('lib/src/features/add/presentation/screens/add_listing_screen.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'{label} not found')
    return text.replace(old, new, 1)


def patch_draft() -> None:
    text = DRAFT.read_text()
    block = '''  /// Every listing type can optionally submit private proof for review.
  bool get supportsLegalVerification => true;

  int get maxLegalDocuments => 6;

  String get verificationTitle {
    switch (category) {
      case ListingCategory.property:
        return 'Build trust with renters & buyers';
      case ListingCategory.yacht:
        return 'Show clients who they are booking with';
      case ListingCategory.motorcycle:
        return 'Add extra trust to this vehicle';
      case ListingCategory.bicycle:
        return 'Add extra trust to this bicycle';
      case ListingCategory.worker:
        return 'Stand out as a serious professional';
    }
  }

  String get verificationBody {
    switch (category) {
      case ListingCategory.property:
        return 'Owners, brokers and authorized representatives are all welcome. If you can show ownership or authorization, send it privately for review. Approved listings receive a blue check and stronger visibility, helping clients understand who they are dealing with and connect more directly.';
      case ListingCategory.yacht:
        return 'Owners, brokers and authorized operators are all welcome. You can privately show ownership, registration or authorization for review. Approved listings receive a blue check and stronger visibility, helping clients book with more confidence.';
      case ListingCategory.motorcycle:
        return 'Anyone can list, but owners or authorized sellers/renters can privately submit registration or ownership proof. Approved listings receive a blue check and stronger visibility so clients can deal with more confidence.';
      case ListingCategory.bicycle:
        return 'Anyone can list. If you have purchase, ownership or business proof, you can send it privately for review. Approved listings receive a blue check and stronger visibility, adding trust for buyers and renters.';
      case ListingCategory.worker:
        return 'Independent professionals, teams and businesses are all welcome. Share credentials, registration, certification or other professional proof privately. Approved profiles receive a blue check and stronger visibility, helping serious clients find you faster.';
    }
  }

  String get verificationProofHint {
    switch (category) {
      case ListingCategory.property:
        return 'Ownership, title, management agreement or authorization';
      case ListingCategory.yacht:
        return 'Registration, ownership or operating authorization';
      case ListingCategory.motorcycle:
        return 'Registration, ownership or authorized dealer/rental proof';
      case ListingCategory.bicycle:
        return 'Purchase, ownership, shop or rental-business proof';
      case ListingCategory.worker:
        return 'License, certification, business registration or professional ID';
    }
  }
'''
    text, count = re.subn(
        r"  bool get requiresLegalDocuments \{.*?  int get maxLegalDocuments => 6;\n",
        block,
        text,
        count=1,
        flags=re.S,
    )
    if count != 1:
        raise SystemExit('listing_draft verification block not found')
    text = text.replace(
        '  /// Properties, yachts and motorcycles submit ownership/registration proof;\n  /// workers submit professional/business proof. Public users only see the\n',
        '  /// Any category may submit ownership, authorization, business or professional proof.\n  /// Public users only see the\n',
        1,
    )
    DRAFT.write_text(text)


def patch_provider() -> None:
    text = PROVIDER.read_text()
    text = replace_once(
        text,
        'if (!state.requiresLegalDocuments) {',
        'if (!state.supportsLegalVerification) {',
        'provider support guard',
    )
    text = text.replace(
        "'Verification proof is used for properties, yachts, motorcycles, and professional listings.',",
        "'Verification proof is optional and available for every listing category.',",
        1,
    )
    marker = '  void removeLegalDocument(int index) {\n'
    camera = '''  Future<void> captureLegalDocument() async {
    if (!state.supportsLegalVerification) return;
    final remaining = state.maxLegalDocuments - state.legalDocuments.length;
    if (remaining <= 0) {
      state = state.copyWith(error: 'Maximum verification documents reached.');
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      maxWidth: 2400,
      maxHeight: 2400,
      requestFullMetadata: false,
    );
    if (file == null) return;
    state = state.copyWith(
      legalDocuments: [...state.legalDocuments, file],
      clearError: true,
    );
  }

'''
    text = replace_once(text, marker, camera + marker, 'removeLegalDocument marker')

    start = text.find('    // Direct-owner / serious-professional trust gate.')
    end = text.find('    // Check the server quota before geocoding or uploading photos.', start)
    if start < 0 or end < 0:
        raise SystemExit('mandatory verification gate block not found')
    text = text[:start] + '''    // Verification is optional. Users can publish immediately and choose to
    // submit private proof for an admin-reviewed blue check and visibility boost.

''' + text[end:]

    text = replace_once(
        text,
        'if (state.requiresLegalDocuments && state.legalDocuments.isNotEmpty) {',
        'if (state.supportsLegalVerification && state.legalDocuments.isNotEmpty) {',
        'document upload condition',
    )
    PROVIDER.write_text(text)


def patch_screen() -> None:
    text = SCREEN.read_text()
    old = '''class _PublishStep extends StatelessWidget {
  const _PublishStep({required this.draft});
  final ListingDraft draft;

  @override
  Widget build(BuildContext context) {
'''
    new = '''class _PublishStep extends ConsumerWidget {
  const _PublishStep({required this.draft});
  final ListingDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
'''
    text = replace_once(text, old, new, '_PublishStep declaration')

    row = '''        if (draft.neighborhood.trim().isNotEmpty)
          _ReviewRow(label: 'Neighborhood', value: draft.neighborhood),
        const SizedBox(height: 16),
'''
    row_new = '''        if (draft.neighborhood.trim().isNotEmpty)
          _ReviewRow(label: 'Neighborhood', value: draft.neighborhood),
        const SizedBox(height: 18),
        _ListingVerificationCard(
          draft: draft,
          onUpload: () => ref.read(addListingProvider.notifier).pickLegalDocuments(),
          onCamera: () => ref.read(addListingProvider.notifier).captureLegalDocument(),
          onRemove: (index) => ref.read(addListingProvider.notifier).removeLegalDocument(index),
        ),
        const SizedBox(height: 16),
'''
    text = replace_once(text, row, row_new, 'publish verification insertion')

    widget = r'''class _ListingVerificationCard extends StatelessWidget {
  const _ListingVerificationCard({
    required this.draft,
    required this.onUpload,
    required this.onCamera,
    required this.onRemove,
  });

  final ListingDraft draft;
  final VoidCallback onUpload;
  final VoidCallback onCamera;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final hasDocs = draft.legalDocuments.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0x332D9CDB),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.verified_user_rounded, color: Color(0xFF5DBBFF)),
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
                            draft.verificationTitle,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'OPTIONAL',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      draft.verificationBody,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x142D9CDB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x332D9CDB)),
            ),
            child: Text(
              'Useful proof: ${draft.verificationProofHint}. Documents stay private and are only reviewed by authorized Swipess admins.',
              style: GoogleFonts.plusJakartaSans(
                color: const Color(0xFFB9DFFF),
                fontSize: 11,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (hasDocs) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < draft.legalDocuments.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 16, color: Color(0xFF5DBBFF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        draft.legalDocuments[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remove document',
                      onPressed: () => onRemove(i),
                      icon: const Icon(Icons.close_rounded, size: 17, color: Colors.white60),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: draft.legalDocuments.length >= draft.maxLegalDocuments ? null : onUpload,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Upload document'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: draft.legalDocuments.length >= draft.maxLegalDocuments ? null : onCamera,
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Take photo'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            hasDocs
                ? '${draft.legalDocuments.length} private document${draft.legalDocuments.length == 1 ? '' : 's'} ready for review after publishing.'
                : 'No document? No problem — you can publish now and verify later.',
            style: GoogleFonts.plusJakartaSans(
              color: hasDocs ? const Color(0xFF8BD0FF) : Colors.white54,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

'''
    marker = 'class _ReviewRow extends StatelessWidget {\n'
    text = replace_once(text, marker, widget + marker, '_ReviewRow marker')
    SCREEN.write_text(text)


patch_draft()
patch_provider()
patch_screen()
