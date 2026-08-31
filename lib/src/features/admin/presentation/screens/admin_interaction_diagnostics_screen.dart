import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/admin/presentation/providers/admin_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Super-admin diagnostic surface for the privacy-minimal interaction telemetry.
///
/// This deliberately shows only routes, normalized touch positions, navigation
/// outcomes and sanitized runtime errors. Typed text, messages, form values and
/// screenshots are never collected by the client diagnostics probe.
class AdminInteractionDiagnosticsScreen extends ConsumerStatefulWidget {
  const AdminInteractionDiagnosticsScreen({super.key});

  @override
  ConsumerState<AdminInteractionDiagnosticsScreen> createState() =>
      _AdminInteractionDiagnosticsScreenState();
}

class _AdminInteractionDiagnosticsScreenState
    extends ConsumerState<AdminInteractionDiagnosticsScreen> {
  String _filter = 'issues';
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await Supabase.instance.client
        .from('app_interaction_diagnostics')
        .select(
          'id,user_id,session_id,event_kind,route_before,route_after,x_norm,y_norm,outcome,error_type,error_message,metadata,created_at',
        )
        .order('created_at', ascending: false)
        .limit(300);
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  bool _visible(Map<String, dynamic> row) {
    final kind = row['event_kind']?.toString() ?? '';
    final outcome = row['outcome']?.toString() ?? '';
    return switch (_filter) {
      'issues' => kind.endsWith('_error') ||
          kind == 'flutter_error' ||
          kind == 'platform_error' ||
          (kind == 'tap' && outcome == 'same_route'),
      'same' => kind == 'tap' && outcome == 'same_route',
      'errors' => kind == 'flutter_error' || kind == 'platform_error',
      'nav' => kind == 'navigation' || outcome == 'route_changed',
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final admin = ref.watch(isAdminProvider);
    return admin.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF080A0F),
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => _Denied(onRetry: () => ref.invalidate(isAdminProvider)),
      data: (allowed) {
        if (!allowed) return const _Denied();
        return Scaffold(
          backgroundColor: AppTheme.dashBg,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Row(
                    children: [
                      const CapBackButton(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DEVELOPER TOOL',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white54,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.7,
                              ),
                            ),
                            Text(
                              'Touch diagnostics',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh diagnostics',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: Text(
                    'Real route/touch outcomes and sanitized runtime errors. Same-page taps are review candidates, not automatically bugs because toggles and in-page actions can intentionally stay on one page.',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white60,
                      fontSize: 10.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (snapshot.hasError) {
                        return _LoadError(error: snapshot.error, onRetry: _refresh);
                      }
                      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                      final visible = rows.where(_visible).toList(growable: false);
                      return RefreshIndicator(
                        onRefresh: () async => _refresh(),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                          children: [
                            _Summary(rows: rows),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: 'Needs review',
                                    selected: _filter == 'issues',
                                    onTap: () => setState(() => _filter = 'issues'),
                                  ),
                                  _FilterChip(
                                    label: 'Same-page taps',
                                    selected: _filter == 'same',
                                    onTap: () => setState(() => _filter = 'same'),
                                  ),
                                  _FilterChip(
                                    label: 'Errors',
                                    selected: _filter == 'errors',
                                    onTap: () => setState(() => _filter = 'errors'),
                                  ),
                                  _FilterChip(
                                    label: 'Navigation',
                                    selected: _filter == 'nav',
                                    onTap: () => setState(() => _filter = 'nav'),
                                  ),
                                  _FilterChip(
                                    label: 'All',
                                    selected: _filter == 'all',
                                    onTap: () => setState(() => _filter = 'all'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (visible.isEmpty)
                              const _Empty()
                            else
                              for (final row in visible) ...[
                                _DiagnosticRow(row: row),
                                const SizedBox(height: 8),
                              ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final taps = rows.where((r) => r['event_kind'] == 'tap').length;
    final same = rows
        .where((r) => r['event_kind'] == 'tap' && r['outcome'] == 'same_route')
        .length;
    final errors = rows
        .where(
          (r) =>
              r['event_kind'] == 'flutter_error' ||
              r['event_kind'] == 'platform_error',
        )
        .length;
    final changed = rows.where((r) => r['outcome'] == 'route_changed').length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Metric(label: 'Taps', value: taps, icon: Icons.touch_app_rounded),
        _Metric(label: 'Same page', value: same, icon: Icons.ads_click_rounded),
        _Metric(label: 'Route changes', value: changed, icon: Icons.route_rounded),
        _Metric(label: 'Errors', value: errors, icon: Icons.bug_report_rounded),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFFF2D6F)),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .65,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFF2D6F) : Colors.white.withAlpha(9),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFF2D6F)
                  : Colors.white.withAlpha(24),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final kind = row['event_kind']?.toString() ?? 'event';
    final outcome = row['outcome']?.toString() ?? '';
    final before = row['route_before']?.toString() ?? '—';
    final after = row['route_after']?.toString() ?? '—';
    final error = row['error_message']?.toString();
    final x = (row['x_norm'] as num?)?.toDouble();
    final y = (row['y_norm'] as num?)?.toDouble();
    final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final isError = kind == 'flutter_error' || kind == 'platform_error';
    final sameTap = kind == 'tap' && outcome == 'same_route';
    final accent = isError
        ? const Color(0xFFFF4458)
        : sameTap
        ? const Color(0xFFFFB800)
        : const Color(0xFF00D4FF);

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(9),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: accent.withAlpha(72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${kind.replaceAll('_', ' ').toUpperCase()}${outcome.isEmpty ? '' : ' · ${outcome.replaceAll('_', ' ').toUpperCase()}'}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .55,
                  ),
                ),
              ),
              if (created != null)
                Text(
                  _time(created.toLocal()),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white46,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            before == after ? before : '$before  →  $after',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (x != null && y != null) ...[
            const SizedBox(height: 5),
            Text(
              'Touch position: ${(x * 100).round()}% across · ${(y * 100).round()}% down',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white54,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              error,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.robotoMono(
                color: const Color(0xFFFFB4B4),
                fontSize: 9.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _time(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${value.month}/${value.day}';
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 42, color: Colors.white30),
          const SizedBox(height: 12),
          Text(
            'Nothing in this filter yet',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white70,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bug_report_outlined, size: 38),
            const SizedBox(height: 12),
            const Text('Could not load touch diagnostics.'),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _Denied extends StatelessWidget {
  const _Denied({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.dashBg,
      body: Center(
        child: TextButton(
          onPressed: onRetry,
          child: Text(onRetry == null ? 'Admin access required' : 'Retry admin check'),
        ),
      ),
    );
  }
}
