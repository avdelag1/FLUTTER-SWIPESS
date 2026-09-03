import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';
import 'package:flutter_swipes/src/features/admin/presentation/providers/admin_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin-only viewer for privacy-minimal interaction diagnostics.
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
          'event_kind,route_before,route_after,x_norm,y_norm,outcome,error_message,created_at',
        )
        .order('created_at', ascending: false)
        .limit(300);
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  void _refresh() => setState(() => _future = _load());

  bool _matches(Map<String, dynamic> row) {
    final kind = row['event_kind']?.toString() ?? '';
    final outcome = row['outcome']?.toString() ?? '';
    return switch (_filter) {
      'issues' => kind == 'flutter_error' ||
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
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, _) => _Denied(
        onRetry: () => ref.invalidate(isAdminProvider),
      ),
      data: (allowed) => allowed ? _buildBody() : const _Denied(),
    );
  }

  Widget _buildBody() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
              child: Text(
                'Routes, touch positions and sanitized runtime errors only. No typed text, messages, passwords or screenshots.',
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
                    return Center(
                      child: TextButton(
                        onPressed: _refresh,
                        child: const Text('Could not load diagnostics — retry'),
                      ),
                    );
                  }

                  final all = snapshot.data ?? const <Map<String, dynamic>>[];
                  final rows = all.where(_matches).toList(growable: false);
                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                      children: [
                        _Summary(rows: all),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _filterChip('Needs review', 'issues'),
                              _filterChip('Same-page taps', 'same'),
                              _filterChip('Errors', 'errors'),
                              _filterChip('Navigation', 'nav'),
                              _filterChip('All', 'all'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (rows.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 52),
                            child: Center(
                              child: Text(
                                'Nothing in this filter yet',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ),
                          )
                        else
                          for (final row in rows) ...[
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
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: const Color(0xFFFF2D6F),
        backgroundColor: Colors.white.withAlpha(9),
        side: BorderSide(
          color: selected
              ? const Color(0xFFFF2D6F)
              : Colors.white.withAlpha(24),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    int count(bool Function(Map<String, dynamic>) test) =>
        rows.where(test).length;
    final taps = count((r) => r['event_kind'] == 'tap');
    final same = count(
      (r) => r['event_kind'] == 'tap' && r['outcome'] == 'same_route',
    );
    final changed = count((r) => r['outcome'] == 'route_changed');
    final errors = count(
      (r) =>
          r['event_kind'] == 'flutter_error' ||
          r['event_kind'] == 'platform_error',
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Metric('Taps', taps),
        _Metric('Same page', same),
        _Metric('Route changes', changed),
        _Metric('Errors', errors),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final int value;

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
      child: Text(
        '$value  ${label.toUpperCase()}',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
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
          Text(
            '${kind.replaceAll('_', ' ').toUpperCase()} · ${outcome.replaceAll('_', ' ').toUpperCase()}',
            style: GoogleFonts.plusJakartaSans(
              color: accent,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
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
              'Touch ${(x * 100).round()}% across · ${(y * 100).round()}% down',
              style: const TextStyle(color: Colors.white54, fontSize: 9.5),
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
}

class _Denied extends StatelessWidget {
  const _Denied({this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: TextButton(
          onPressed: onRetry,
          child: Text(onRetry == null ? 'Admin access required' : 'Retry admin check'),
        ),
      ),
    );
  }
}
