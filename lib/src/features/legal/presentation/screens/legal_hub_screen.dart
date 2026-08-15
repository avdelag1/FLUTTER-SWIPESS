import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';

class LegalHubScreen extends ConsumerStatefulWidget {
  const LegalHubScreen({super.key});

  @override
  ConsumerState<LegalHubScreen> createState() => _LegalHubScreenState();
}

class _LegalHubScreenState extends ConsumerState<LegalHubScreen> {
  bool _isOwner = false;
  String? _expandedCategory;
  Map<String, String>? _selectedIssue;
  final _descriptionController = TextEditingController();

  static const _clientCategories = [
    {
      'id': 'landlord-issues',
      'title': 'Landlord Issues',
      'icon': Icons.home_rounded,
      'description': 'Problems with your landlord or property owner',
      'subcategories': [
        {
          'id': 'lease-violation',
          'title': 'Lease Violations',
          'description': 'Landlord not following the lease terms',
        },
        {
          'id': 'security-deposit',
          'title': 'Security Deposit Disputes',
          'description': 'Issues recovering your deposit',
        },
        {
          'id': 'maintenance',
          'title': 'Maintenance Issues',
          'description': 'Landlord not maintaining the property',
        },
      ],
    },
    {
      'id': 'rent-issues',
      'title': 'Rent & Payment Issues',
      'icon': Icons.attach_money_rounded,
      'description': 'Disputes about rent payments or charges',
      'subcategories': [
        {
          'id': 'rent-increase',
          'title': 'Unlawful Rent Increase',
          'description': 'Rent raised without proper notice',
        },
        {
          'id': 'hidden-fees',
          'title': 'Hidden Fees',
          'description': 'Unexpected charges not in the lease',
        },
      ],
    },
    {
      'id': 'contract-issues',
      'title': 'Contract & Agreement Issues',
      'icon': Icons.description_rounded,
      'description': 'Problems with rental agreements or contracts',
      'subcategories': [
        {
          'id': 'unfair-terms',
          'title': 'Unfair Contract Terms',
          'description': 'One-sided or illegal clauses',
        },
        {
          'id': 'early-termination',
          'title': 'Early Termination',
          'description': 'Need to break lease early',
        },
      ],
    },
  ];

  static const _ownerCategories = [
    {
      'id': 'tenant-issues',
      'title': 'Tenant Issues',
      'icon': Icons.person_off_rounded,
      'description': 'Problems with tenants or renters',
      'subcategories': [
        {
          'id': 'non-payment',
          'title': 'Non-Payment of Rent',
          'description': 'Tenant not paying rent on time',
        },
        {
          'id': 'property-damage',
          'title': 'Property Damage',
          'description': 'Tenant damaged the property',
        },
        {
          'id': 'eviction-process',
          'title': 'Eviction Process',
          'description': 'Need help with legal eviction',
        },
      ],
    },
    {
      'id': 'contract-legal',
      'title': 'Lease & Contract Agreements',
      'icon': Icons.description_rounded,
      'description': 'Legal help with contracts and leases',
      'subcategories': [
        {
          'id': 'lease-creation',
          'title': 'Lease Agreement Creation',
          'description': 'Create legally binding leases',
        },
        {
          'id': 'rental-rules',
          'title': 'Rental Rules Documentation',
          'description': 'Create enforceable property rules',
        },
      ],
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitRequest(LegalServicePackage? pkg) {
    if ((_selectedIssue == null && pkg == null) ||
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an issue and provide a description'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Legal help request submitted!')),
    );
    Navigator.pop(context);
    setState(() {
      _selectedIssue = null;
      _descriptionController.clear();
    });
  }

  void _showSubmissionSheet([LegalServicePackage? pkg]) {
    if (pkg != null) {
      _descriptionController.text =
          'I\'m interested in the "${pkg.name}" legal service package. Please contact me with more details.';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom + 32,
            left: 20,
            right: 20,
            top: 32,
          ),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: MatteSurface.ink(context), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pkg != null ? 'REQUEST SERVICE' : 'DESCRIBE ISSUE',
                style: AppTheme.displayItalic.copyWith(fontSize: 24),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: TextStyle(color: MatteSurface.ink(context)),
                decoration: InputDecoration(
                  hintText: 'Provide details about your situation...',
                  hintStyle: TextStyle(color: MatteSurface.faint(context)),
                  filled: true,
                  fillColor: Colors.transparent,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: MatteSurface.ink(context),
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: MatteSurface.ink(context),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () => _submitRequest(pkg),
                  child: const Text(
                    'SUBMIT SECURELY',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final categories = _isOwner ? _ownerCategories : _clientCategories;

    return NeoNaiveScaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, top + 12, 20, 140),
        children: [
          Row(
            children: [
              CapBackButton(onTap: () => Navigator.pop(context)),
              Spacer(),
              // Mode Toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: MatteSurface.ink(context),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToggleBtn(
                      label: 'CLIENT',
                      isActive: !_isOwner,
                      onTap: () => setState(() => _isOwner = false),
                    ),
                    const SizedBox(width: 4),
                    _ToggleBtn(
                      label: 'OWNER',
                      isActive: _isOwner,
                      onTap: () => setState(() => _isOwner = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 32),

          // PRIMARY FEATURE CARD
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: MatteSurface.ink(context), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: MatteSurface.ink(context),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.gavel_rounded,
                    color: MatteSurface.ink(context),
                    size: 40,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'REQUEST\nINDEPENDENT\nLEGAL HELP',
                  textAlign: TextAlign.center,
                  style: AppTheme.displayItalic.copyWith(
                    fontSize: 40,
                    height: 0.9,
                    letterSpacing: -1,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Describe the legal topic you want help with. Provider availability, identity, license, jurisdiction, confidentiality, scope, timing, price, and engagement terms must be confirmed directly.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: MatteSurface.muted(context),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 40),

          Row(
            children: [
              Text(
                'ISSUE CATEGORIES',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: MatteSurface.faint(context),
                  letterSpacing: 2,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Divider(color: MatteSurface.faint(context), height: 1),
              ),
            ],
          ),
          const SizedBox(height: 24),

          for (final cat in categories)
            _CategoryTile(
              category: cat,
              isExpanded: _expandedCategory == cat['id'],
              selectedSubId:
                  (_selectedIssue != null &&
                      _selectedIssue!['category'] == cat['id'])
                  ? _selectedIssue!['subcategory']
                  : null,
              onToggle: () {
                AppHaptics.light();
                setState(() {
                  _expandedCategory = _expandedCategory == cat['id']
                      ? null
                      : cat['id'] as String;
                  _selectedIssue = null;
                });
              },
              onSubSelect: (subId) {
                AppHaptics.selection();
                setState(() {
                  _selectedIssue = {
                    'category': cat['id'] as String,
                    'subcategory': subId,
                  };
                });
                _showSubmissionSheet();
              },
            ),

          SizedBox(height: 48),

          // SERVICE PACKAGES BUTTON
          GestureDetector(
            onTap: () => context.push(AppPaths.clientLegalServices),
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: MatteSurface.ink(context),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SERVICE PACKAGES',
                          style: AppTheme.displayItalic.copyWith(fontSize: 24),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Browse currently listed service options',
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.muted(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: MatteSurface.ink(context),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.label,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isActive ? Colors.black : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isExpanded,
    required this.selectedSubId,
    required this.onToggle,
    required this.onSubSelect,
  });

  final Map<String, dynamic> category;
  final bool isExpanded;
  final String? selectedSubId;
  final VoidCallback onToggle;
  final Function(String) onSubSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MatteSurface.ink(context), width: 1.5),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onToggle,
            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: MatteSurface.ink(context), width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category['icon'] as IconData,
                color: MatteSurface.ink(context),
                size: 20,
              ),
            ),
            title: Text(
              category['title'] as String,
              style: TextStyle(
                color: MatteSurface.ink(context),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              category['description'] as String,
              style: TextStyle(
                color: MatteSurface.muted(context),
                fontSize: 11,
              ),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: MatteSurface.ink(context),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: (category['subcategories'] as List).map((sub) {
                  final isSelected = selectedSubId == sub['id'];
                  return GestureDetector(
                    onTap: () => onSubSelect(sub['id'] as String),
                    child: Container(
                      margin: EdgeInsets.only(top: 8),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: MatteSurface.ink(context),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sub['title'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sub['description'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.black54
                                        : Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: isSelected ? Colors.black : Colors.white,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
