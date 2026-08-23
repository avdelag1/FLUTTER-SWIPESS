import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/ai/domain/user_memory.dart';
import 'package:flutter_swipes/src/features/ai/presentation/providers/ai_providers.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cap MemoryDrawer — AI Memory sheet (Bolt/Brain via edge functions).
Future<void> showMemoryDrawer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _MemoryDrawer(),
  );
}

class _MemoryDrawer extends ConsumerStatefulWidget {
  const _MemoryDrawer();

  @override
  ConsumerState<_MemoryDrawer> createState() => _MemoryDrawerState();
}

class _MemoryDrawerState extends ConsumerState<_MemoryDrawer> {
  MemoryCategory? _filter;
  bool _adding = false;
  MemoryCategory _newCat = MemoryCategory.fact;
  final _title = TextEditingController();
  final _content = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) return;
    setState(() => _saving = true);
    AppHaptics.medium();
    final ok = await ref
        .read(memoriesProvider.notifier)
        .add(
          category: _newCat,
          title: _title.text.trim(),
          content: _content.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) {
        _adding = false;
        _title.clear();
        _content.clear();
      }
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save memory — check session / schema'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(memoriesProvider);
    final edgeReady = ref.watch(aiEdgeReadyProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final height = MediaQuery.sizeOf(context).height * 0.78;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF18181B), Color(0xFF09090B)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: Color(0xFF22D3EE),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI MEMORY',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Text(
                          edgeReady
                              ? 'Brain online · Supabase Edge AI'
                              : 'Brain paused',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _adding = !_adding),
                    icon: Icon(
                      _adding ? Icons.close_rounded : Icons.add_rounded,
                      color: AppTheme.brandPrimary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _CatChip(
                    label: 'All',
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  for (final c in MemoryCategory.values)
                    _CatChip(
                      label: c.label,
                      selected: _filter == c,
                      onTap: () => setState(() => _filter = c),
                    ),
                ],
              ),
            ),
            if (_adding)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final c in MemoryCategory.values)
                            _CatChip(
                              label: c.label,
                              selected: _newCat == c,
                              onTap: () => setState(() => _newCat = c),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _title,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Title',
                        hintStyle: const TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _content,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'What should the brain remember?',
                        hintStyle: const TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(_saving ? 'Saving…' : 'Save memory'),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                error: (_, _) => Center(
                  child: TextButton(
                    onPressed: () =>
                        ref.read(memoriesProvider.notifier).refresh(),
                    child: const Text('Could not load — retry'),
                  ),
                ),
                data: (items) {
                  final filtered = _filter == null
                      ? items
                      : items.where((m) => m.category == _filter).toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No memories yet — teach the brain preferences, contacts, and facts.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final m = filtered[i];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.category.label.toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF22D3EE),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 10,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    m.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    m.content,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => ref
                                  .read(memoriesProvider.notifier)
                                  .remove(m.id),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
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
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.brandPrimary
                : Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.brandPrimary : Colors.white24,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
