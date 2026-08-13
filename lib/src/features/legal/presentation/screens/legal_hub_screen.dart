import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/features/legal/domain/legal_service_package.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/legal_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _isSubmitting = false;

  static const _clientCategories = [
    {
      'id': 'landlord-issues',
      'title': 'Landlord Issues',
      'icon': Icons.home_rounded,
      'description': 'Problems with your landlord or property owner',
      'subcategories': [
        {'id': 'lease-violation', 'title': 'Lease Violations', 'description': 'Landlord not following the lease terms'},
        {'id': 'security-deposit', 'title': 'Security Deposit Disputes', 'description': 'Issues recovering your deposit'},
        {'id': 'maintenance', 'title': 'Maintenance Issues', 'description': 'Landlord not maintaining the property'},
      ]
    },
    {
      'id': 'rent-issues',
      'title': 'Rent & Payment Issues',
      'icon': Icons.attach_money_rounded,
      'description': 'Disputes about rent payments or charges',
      'subcategories': [
        {'id': 'rent-increase', 'title': 'Unlawful Rent Increase', 'description': 'Rent raised without proper notice'},
        {'id': 'hidden-fees', 'title': 'Hidden Fees', 'description': 'Unexpected charges not in the lease'},
      ]
    },
    {
      'id': 'contract-issues',
      'title': 'Contract & Agreement Issues',
      'icon': Icons.description_rounded,
      'description': 'Problems with rental agreements or contracts',
      'subcategories': [
        {'id': 'unfair-terms', 'title': 'Unfair Contract Terms', 'description': 'One-sided or illegal clauses'},
        {'id': 'early-termination', 'title': 'Early Termination', 'description': 'Need to break lease early'},
      ]
    }
  ];

  static const _ownerCategories = [
    {
      'id': 'tenant-issues',
      'title': 'Tenant Issues',
      'icon': Icons.person_off_rounded,
      'description': 'Problems with tenants or renters',
      'subcategories': [
        {'id': 'non-payment', 'title': 'Non-Payment of Rent', 'description': 'Tenant not paying rent on time'},
        {'id': 'property-damage', 'title': 'Property Damage', 'description': 'Tenant damaged the property'},
        {'id': 'eviction-process', 'title': 'Eviction Process', 'description': 'Need help with legal eviction'},
      ]
    },
    {
      'id': 'contract-legal',
      'title': 'Lease & Contract Agreements',
      'icon': Icons.description_rounded,
      'description': 'Legal help with contracts and leases',
      'subcategories': [
        {'id': 'lease-creation', 'title': 'Lease Agreement Creation', 'description': 'Create legally binding leases'},
        {'id': 'rental-rules', 'title': 'Rental Rules Documentation', 'description': 'Create enforceable property rules'},
      ]
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest(LegalServicePackage? pkg) async {
    if ((_selectedIssue == null && pkg == null) || _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an issue and provide a description')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      final repo = ref.read(legalRepositoryProvider);
      final year = DateTime.now().year;
      final random = (Random().nextInt(9000) + 1000).toString();
      
      await repo.submitLegalCase(
        caseNumber: 'LC-$year-$random',
        title: pkg != null ? 'Service Request: ${pkg.id}' : 'Legal Support: ${_selectedIssue?['category']}',
        description: _descriptionController.text.trim(),
        caseType: 'user_complaint',
        priority: 'medium',
        partiesInvolved: {
          'requester_role': _isOwner ? 'owner' : 'client',
          'requested_package_id': pkg?.id,
          'category': _selectedIssue?['category'],
          'subcategory': _selectedIssue?['subcategory'],
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Legal help request submitted!')),
        );
        Navigator.pop(context);
        setState(() {
          _selectedIssue = null;
          _descriptionController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSubmissionSheet([LegalServicePackage? pkg]) {
    if (pkg != null) {
      _descriptionController.text = 'I\'m interested in the "${pkg.name}" legal service package. Please contact me with more details.';
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.dashElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom + 32,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pkg != null ? 'REQUEST SERVICE' : 'DESCRIBE ISSUE', 
                style: AppTheme.displayItalic.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Provide details about your situation...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _isSubmitting ? null : () => _submitRequest(pkg),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SUBMIT SECURELY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
    final packagesAsync = ref.watch(legalServicePackagesProvider);
    final top = MediaQuery.paddingOf(context).top;
    final categories = _isOwner ? _ownerCategories : _clientCategories;

    return NeoNaiveScaffold(
      body: ListView(
            padding: EdgeInsets.fromLTRB(24, top + 24, 24, 140),
            children: [
              Row(
                children: [
                  GlassIconCircle(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  // Mode Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(12),
                      borderRadius: BorderRadius.circular(20),
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
                        _ToggleBtn(
                          label: 'OWNER',
                          isActive: _isOwner,
                          onTap: () => setState(() => _isOwner = true),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 32),
              
              Text('LEGAL CENTER', style: AppTheme.displayItalic.copyWith(fontSize: 48, height: 0.9)),
              const SizedBox(height: 16),
              Text(
                'Secure legal terminal for Swipess protocols, terms of use, and professional legal dispatch.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              
              // Top Actions
              Row(
                children: [
                  Expanded(
                    child: _ActionCard(
                      title: 'CONTRACTS',
                      icon: Icons.edit_document,
                      color: Colors.white.withAlpha(12),
                      onTap: () => context.push(AppPaths.clientContracts),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionCard(
                      title: 'LAWYERS',
                      icon: Icons.gavel_rounded,
                      color: Colors.white.withAlpha(12),
                      onTap: () => context.push(AppPaths.clientLegalServices),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Issues Section
              Text('REPORT AN ISSUE', style: AppTheme.displayItalic.copyWith(fontSize: 24)),
              const SizedBox(height: 16),
              for (final cat in categories)
                _CategoryTile(
                  category: cat,
                  isExpanded: _expandedCategory == cat['id'],
                  selectedSubId: (_selectedIssue != null && _selectedIssue!['category'] == cat['id']) ? _selectedIssue!['subcategory'] : null,
                  onToggle: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _expandedCategory = _expandedCategory == cat['id'] ? null : cat['id'] as String;
                      _selectedIssue = null;
                    });
                  },
                  onSubSelect: (subId) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedIssue = {'category': cat['id'] as String, 'subcategory': subId};
                    });
                    _showSubmissionSheet();
                  },
                ),
                
              const SizedBox(height: 48),
              
              // Service Packages Section
              Text('SERVICE PACKAGES', style: AppTheme.displayItalic.copyWith(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                'Browse currently listed service options and submit a request.',
                style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              
              packagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.brandPrimary)),
                error: (e, _) => Center(child: Text('Failed to load packages: $e', style: const TextStyle(color: Colors.white54))),
                data: (packages) {
                  if (packages.isEmpty) return const Text('No packages available.', style: TextStyle(color: Colors.white54));
                  return Column(
                    children: packages.map((pkg) => _PackageCard(
                      pkg: pkg,
                      onTap: () => _showSubmissionSheet(pkg),
                    )).toList(),
                  );
                },
              ),
              
              const SizedBox(height: 48),
            ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({required this.label, required this.isActive, required this.onTap});
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isActive ? Colors.black : Colors.white54,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.title, required this.icon, required this.color, required this.onTap});
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.displayItalic.copyWith(fontSize: 16)),
          ],
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isExpanded
              ? AppTheme.brandPrimary
              : Colors.white.withAlpha(25),
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: AppTheme.brandPrimary.withAlpha(40),
                  blurRadius: 18,
                ),
              ]
            : const [],
      ),
      child: Column(
        children: [
          ListTile(
            onTap: onToggle,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Icon(category['icon'] as IconData, color: isExpanded ? AppTheme.brandPrimary : Colors.white),
            title: Text(category['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            subtitle: Text(category['description'] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white54),
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
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.brandPrimary.withAlpha(20) : Colors.white.withAlpha(5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.brandPrimary
                              : Colors.transparent,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppTheme.brandPrimary.withAlpha(50),
                                  blurRadius: 16,
                                ),
                              ]
                            : const [],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sub['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text(sub['description'] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: isSelected ? AppTheme.brandPrimary : Colors.white30),
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

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.pkg, required this.onTap});
  final LegalServicePackage pkg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withAlpha(15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(pkg.name, style: AppTheme.displayItalic.copyWith(fontSize: 20)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('STARTING AT', style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text('\$${pkg.price.toStringAsFixed(0)}', style: const TextStyle(color: AppTheme.brandPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ESTIMATED: ${pkg.duration ?? '${pkg.durationDays} DAYS'}',
                style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
            const SizedBox(height: 16),
            for (final feature in pkg.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.brandPrimary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
