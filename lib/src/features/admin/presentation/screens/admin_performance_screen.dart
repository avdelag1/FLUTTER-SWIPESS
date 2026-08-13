import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap `AdminPerformanceDashboard` — Lighthouse snapshot from the Cap source.
class AdminPerformanceScreen extends ConsumerWidget {
  const AdminPerformanceScreen({super.key});

  static const scores = {
    'Performance': 65,
    'Accessibility': 82,
    'Best Practices': 96,
    'SEO': 100,
  };

  static const vitals = [
    ('FCP', '4.4s', true),
    ('LCP', '5.7s', true),
    ('TBT', '0ms', false),
    ('CLS', '0', false),
    ('SI', '6.1s', true),
  ];

  static const issues = [
    (
      'Improve image delivery',
      'Swipess-logo.webp is oversized vs display size. Convert PNG logos to modern formats.'
    ),
    (
      'Reduce unused JavaScript',
      'vendor.js / supabase.js still ship unused code. Prefer dynamic imports.'
    ),
    (
      'Reduce unused CSS',
      'index.css transfers unused rules on first load.'
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminShell(
      title: t(ref, 'flutter.adminPerformance', 'Performance'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'PageSpeed snapshot (Cap source)',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final e in scores.entries)
                Container(
                  width: 150,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withAlpha(24)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${e.value}',
                        style: GoogleFonts.plusJakartaSans(
                          color: e.value >= 90
                              ? const Color(0xFF10B981)
                              : AppTheme.brandPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        e.key,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          for (final v in vitals)
            ListTile(
              dense: true,
              title: Text(
                v.$1,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: Text(
                v.$2,
                style: GoogleFonts.plusJakartaSans(
                  color: v.$3 ? AppTheme.brandPrimary : const Color(0xFF10B981),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 8),
          for (final issue in issues)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.$1,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    issue.$2,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
