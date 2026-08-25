import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/admin/presentation/widgets/admin_shell.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin performance + infrastructure capacity dashboard.
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

  Future<Map<String, dynamic>> _loadUsage() async {
    final result = await Supabase.instance.client.rpc('admin_platform_usage');
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> _loadGuardrails() async {
    final result = await Supabase.instance.client.rpc('admin_content_guardrails');
    return Map<String, dynamic>.from(result as Map);
  }

  static String _bytes(num value) {
    final bytes = value.toDouble();
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${bytes.toStringAsFixed(0)} B';
  }

  Widget _metric(String label, String value, IconData icon) {
    return Container(
      width: 165,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
        color: Colors.white.withValues(alpha: .04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminShell(
      title: t(ref, 'flutter.adminPerformance', 'Performance'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _sectionTitle(
            'Infrastructure & capacity',
            subtitle:
                'Live Supabase database, storage and platform-volume snapshot. One media file can be reused across multiple app surfaces without duplicating storage.',
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, dynamic>>(
            future: _loadUsage(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Text(
                  'Infrastructure metrics unavailable for this account.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                );
              }
              final data = snapshot.data!;
              final buckets = (data['buckets'] as List?) ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _metric('Database', _bytes(data['database_bytes'] ?? 0), Icons.storage_rounded),
                      _metric('File storage', _bytes(data['storage_bytes'] ?? 0), Icons.cloud_rounded),
                      _metric('Stored files', '${data['storage_objects'] ?? 0}', Icons.perm_media_rounded),
                      _metric('Listings', '${data['listings'] ?? 0}', Icons.view_carousel_rounded),
                      _metric('Events', '${data['events'] ?? 0}', Icons.event_rounded),
                      _metric('Users', '${data['users'] ?? 0}', Icons.people_alt_rounded),
                    ],
                  ),
                  if (buckets.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Storage by bucket',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final raw in buckets.take(10))
                      if (raw is Map)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${raw['bucket']}',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            '${raw['objects']} files',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                          trailing: Text(
                            _bytes((raw['bytes'] as num?) ?? 0),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          _sectionTitle(
            'Content guardrails',
            subtitle:
                'Live account limits and video policy. Super-admin changes are enforced by the database, not only by the app UI.',
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _loadGuardrails(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Text(
                  'Content guardrails unavailable for this account.',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                );
              }
              final data = snapshot.data!;
              final limits = (data['limits'] as List?) ?? const [];
              final media = (data['media_rules'] as List?) ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active content limits',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final raw in limits)
                    if (raw is Map)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.shield_outlined, color: Colors.white70, size: 18),
                        title: Text(
                          '${raw['tier']}'.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          'Listings: ${raw['max_active_listings'] ?? 'Unlimited'}  ·  Events: ${raw['max_active_events'] ?? 'Unlimited'}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  const SizedBox(height: 12),
                  Text(
                    'Video policy',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final raw in media)
                    if (raw is Map)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          raw['video_enabled'] == true
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          color: raw['video_enabled'] == true
                              ? AppTheme.brandPrimary
                              : Colors.white38,
                          size: 18,
                        ),
                        title: Text(
                          '${raw['content_type']}',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          raw['video_enabled'] == true
                              ? '1 video · ${raw['max_duration_seconds']}s max · ${_bytes((raw['max_file_size_bytes'] as num?) ?? 0)} · autoplay preview ${raw['autoplay_preview'] == true ? 'on' : 'off'}'
                              : 'Video disabled',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
          const SizedBox(height: 26),
          Text(
            'PageSpeed snapshot (Cap source)',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
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
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white, width: 1.5),
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
                          color: Colors.white,
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
        ],
      ),
    );
  }
}
