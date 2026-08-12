import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/providers/nav_tab_provider.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Capacitor Intel Core / Ask AI shell (full LLM awaits API key).
Future<void> showIntelCoreSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xF20A0A0C),
    builder: (context) => const _IntelCoreSheet(),
  );
}

class _IntelCoreSheet extends ConsumerStatefulWidget {
  const _IntelCoreSheet();

  @override
  ConsumerState<_IntelCoreSheet> createState() => _IntelCoreSheetState();
}

class _IntelCoreSheetState extends ConsumerState<_IntelCoreSheet> {
  final _controller = TextEditingController();
  bool _showHistory = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.92;
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    _RoundIcon(
                      icon: Icons.menu_rounded,
                      onTap: () => setState(() => _showHistory = !_showHistory),
                    ),
                    const Spacer(),
                    Column(
                      children: [
                        Text(
                          'INTEL CORE',
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.brandPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          'ONLINE',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _RoundIcon(
                      icon: Icons.auto_awesome_rounded,
                      color: AppTheme.brandPrimary,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _RoundIcon(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    Text(
                      'Ask for properties, workers, seekers, or filters. Full AI answers need an API key — quick jumps work now.',
                      style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    _ActionPill(
                      label: 'SWIPE DECK',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ClientSwipeContainer(
                              categoryId: 'property',
                              categoryTitle: 'PROPERTIES',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _ActionPill(
                      label: 'APPLYING SEARCH FILTERS',
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(navTabProvider.notifier).set(NavTab.dashboard);
                      },
                    ),
                    const SizedBox(height: 10),
                    _ActionPill(
                      label: 'OPEN SEEKERS',
                      onTap: () {
                        Navigator.pop(context);
                        ref.read(navTabProvider.notifier).set(NavTab.seekers);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.paddingOf(context).bottom + 12,
                ),
                child: Column(
                  children: [
                    Text(
                      '✨ AI-powered · Answers are generated by AI. AI can make mistakes. Consider verifying important information.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF14141A),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.white.withAlpha(50)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.timer_outlined, color: Colors.white.withAlpha(120), size: 20),
                                const SizedBox(width: 8),
                                Icon(Icons.mic_none_rounded, color: Colors.white.withAlpha(120), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Ask anything...',
                                      hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                                    ),
                                    onSubmitted: (_) => _submit(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _submit,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withAlpha(20),
                              border: Border.all(color: Colors.white.withAlpha(40)),
                            ),
                            child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showHistory)
            Positioned.fill(
              child: Row(
                children: [
                  Container(
                    width: MediaQuery.sizeOf(context).width * 0.78,
                    color: const Color(0xF214141A),
                    child: SafeArea(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              Text(
                                'HISTORY',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'CORE ONLINE',
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppTheme.brandPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => setState(() => _showHistory = false),
                                icon: const Icon(Icons.close, color: Colors.white70),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => setState(() => _showHistory = false),
                            child: Text(
                              '+ NEW CHAT',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppTheme.brandPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          for (final item in const [
                            'Find people looking to buy houses',
                            'Find maintenance workers',
                            'Show me all rental properties',
                            'Show me available houses',
                          ])
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(10),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withAlpha(20)),
                              ),
                              child: Text(item, style: const TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _showHistory = false),
                      child: Container(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _submit() {
    HapticFeedback.selectionClick();
    final q = _controller.text.trim().toLowerCase();
    Navigator.pop(context);
    if (q.contains('seeker') || q.contains('worker') || q.contains('hire')) {
      ref.read(navTabProvider.notifier).set(NavTab.seekers);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ClientSwipeContainer(
          categoryId: 'property',
          categoryTitle: 'PROPERTIES',
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withAlpha(14),
          border: Border.all(color: Colors.white.withAlpha(35)),
        ),
        child: Icon(icon, color: color ?? Colors.white, size: 18),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withAlpha(30)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.brandPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
