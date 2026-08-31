import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/native/privacy_screen.dart';
import 'package:flutter_swipes/src/core/providers/chrome_visibility_provider.dart';
import 'package:flutter_swipes/src/core/providers/overlay_modals_provider.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/routing/app_router.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_swipes/src/core/widgets/genie_panel.dart';
import 'package:flutter_swipes/src/core/widgets/swipe_vertical_dismiss.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/providers/documents_provider.dart';
import 'package:flutter_swipes/src/features/documents/presentation/widgets/document_preview_dialog.dart';
import 'package:flutter_swipes/src/features/profile/domain/models/vap_id_card.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_card_theme_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/providers/vap_id_provider.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/themed_vap_card.dart';

/// PEARL / Virtual ID presentation overlay opened from the persistent dock.
///
/// Opening it hides the shared header/dock (like listing detail and event
/// reels) so the card can expand into a full view of the member's info.
/// Card-specific tools stay on the ID itself and collapse after a beat.
class VapIdModal extends ConsumerStatefulWidget {
  const VapIdModal({super.key});

  @override
  ConsumerState<VapIdModal> createState() => _VapIdModalState();
}

class _VapIdModalState extends ConsumerState<VapIdModal> {
  Timer? _controlsTimer;
  Timer? _expandTimer;
  final _scrollController = ScrollController();
  bool _controlsVisible = true;
  bool _cardExpanded = false;

  static const _controlsStayMs = 6800;
  static const _expandDelayMs = 320;

  @override
  void initState() {
    super.initState();
    ref.read(chromeVisibilityProvider.notifier).hide();
    _armControlsTimer();
    _expandTimer = Timer(const Duration(milliseconds: _expandDelayMs), () {
      if (!mounted) return;
      setState(() => _cardExpanded = true);
    });
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _expandTimer?.cancel();
    _scrollController.dispose();
    ref.read(chromeVisibilityProvider.notifier).show();
    super.dispose();
  }

  void _armControlsTimer() {
    _controlsTimer?.cancel();
    if (!_controlsVisible) return;
    _controlsTimer = Timer(
      const Duration(milliseconds: _controlsStayMs),
      _collapseControls,
    );
  }

  void _keepControlsAlive() {
    if (_controlsVisible) _armControlsTimer();
  }

  void _showControls() {
    _expandTimer?.cancel();
    AppHaptics.light();
    setState(() {
      _cardExpanded = false;
      _controlsVisible = true;
    });
    _armControlsTimer();
  }

  void _collapseControls() {
    if (!mounted || !_controlsVisible) return;
    _controlsTimer?.cancel();
    _expandTimer?.cancel();
    setState(() => _controlsVisible = false);

    // Finish the control fade first, then let the ID breathe into the freed
    // space. The overshoot curve below gives a restrained elastic finish.
    _expandTimer = Timer(
      const Duration(milliseconds: _expandDelayMs),
      () {
        if (!mounted || _controlsVisible) return;
        setState(() => _cardExpanded = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PrivacyScreenGuard(
      child: GeniePanel(
        barrierColor: const Color(0xE6000000),
        onDismissed: () =>
            ref.read(overlayModalsProvider.notifier).closeVapId(),
        builder: (context, dismiss) {
          return SafeArea(
            minimum: const EdgeInsets.all(2),
            child: _buildBody(context, dismiss),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, VoidCallback dismiss) {
    final async = ref.watch(vapIdProvider);
    final docs = ref.watch(documentsProvider);
    final theme = ref.watch(vapCardThemeProvider);
    final userId = ref.watch(currentUserProvider)?.id ?? 'resident';

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
      error: (_, _) => Center(
        child: TextButton(
          onPressed: () => ref.read(vapIdProvider.notifier).refresh(),
          child: Text(
            t(ref, 'flutter.vapRetry', 'Could not load PEARL — retry'),
          ),
        ),
      ),
      data: (card) {
        final data = card ?? VapIdCard(userId: userId);
        final slice = userId.length >= 8 ? userId.substring(0, 8) : userId;
        final idNumber = 'NX-${slice.toUpperCase()}';
        final validationUrl = 'https://swipess.com/vap-validate/$userId';
        final duration = Duration(
          milliseconds: _cardExpanded ? 720 : 440,
        );
        final curve = _cardExpanded
            ? const Cubic(0.18, 1.16, 0.28, 1.0)
            : Curves.easeOutCubic;

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // The Virtual ID lives in a root overlay, outside DashboardShell's
            // normal scroll listener. Forward its own scroll updates so the
            // shared header + bottom dock hide/reveal exactly like every page.
            if (notification.depth == 0 &&
                notification.metrics.axis == Axis.vertical &&
                notification is ScrollUpdateNotification) {
              ref
                  .read(chromeVisibilityProvider.notifier)
                  .onScroll(
                    pixels: notification.metrics.pixels,
                    delta: notification.scrollDelta ?? 0,
                  );
            }
            return false;
          },
          child: SwipeVerticalDismiss(
            scrollController: _scrollController,
            onDismiss: dismiss,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _keepControlsAlive(),
              child: AnimatedPadding(
                duration: duration,
                curve: curve,
                padding: EdgeInsets.fromLTRB(
                  _cardExpanded ? 0 : 6,
                  _cardExpanded ? 0 : 8,
                  _cardExpanded ? 0 : 6,
                  _cardExpanded ? 0 : 8,
                ),
                child: AnimatedScale(
                  scale: _cardExpanded ? 1 : 0.988,
                  duration: duration,
                  curve: curve,
                  alignment: Alignment.center,
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      ThemedVapCard(
                        theme: theme,
                        data: data,
                        idNumber: idNumber,
                        validationUrl: validationUrl,
                        docsAsync: docs,
                        scrollController: _scrollController,
                        onPreview: (doc) =>
                            showDocumentPreviewDialog(context, doc),
                        onManageDocuments: _openDocuments,
                      ),
                      // Keep the card tools at the top edge of the ID instead
                      // of floating over the person's name/location.
                      Positioned(
                        top: 12,
                        right: 22,
                        child: _CardControlDock(
                          expanded: _controlsVisible,
                          onExpand: _showControls,
                          onCollapse: () {
                            AppHaptics.selection();
                            _collapseControls();
                          },
                          onDocuments: _openDocuments,
                          onStyle: () {
                            AppHaptics.selection();
                            ref
                                .read(vapCardThemeIndexProvider.notifier)
                                .cycle();
                            _armControlsTimer();
                          },
                          onEdit: _edit,
                          onClose: dismiss,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDocuments() async {
    AppHaptics.selection();
    final router = ref.read(appRouterProvider);
    ref.read(overlayModalsProvider.notifier).closeVapId();
    await Future<void>.delayed(const Duration(milliseconds: 90));
    router.go(AppPaths.documents);
  }

  void _edit() {
    AppHaptics.selection();
    final router = ref.read(appRouterProvider);
    ref.read(overlayModalsProvider.notifier).closeVapId();
    router.go(AppPaths.clientVapIdEdit);
  }
}

/// One quiet affordance in presentation mode; one compact tool dock when open.
/// This keeps editing power available without permanently shrinking the ID.
class _CardControlDock extends StatelessWidget {
  const _CardControlDock({
    required this.expanded,
    required this.onExpand,
    required this.onCollapse,
    required this.onDocuments,
    required this.onStyle,
    required this.onEdit,
    required this.onClose,
  });

  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final VoidCallback onDocuments;
  final VoidCallback onStyle;
  final VoidCallback onEdit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 330),
      curve: Curves.easeOutBack,
      alignment: Alignment.centerRight,
      child: DecoratedBox(
        key: ValueKey(expanded),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(expanded ? 104 : 82),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withAlpha(38)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(90),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: expanded
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Round(
                      icon: Icons.visibility_off_outlined,
                      tooltip: 'Hide card controls',
                      onTap: onCollapse,
                    ),
                    _Round(
                      icon: Icons.folder_copy_outlined,
                      tooltip: 'Documents',
                      onTap: onDocuments,
                    ),
                    _Round(
                      icon: Icons.palette_outlined,
                      tooltip: 'Card style',
                      onTap: onStyle,
                    ),
                    _Round(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit card',
                      onTap: onEdit,
                    ),
                    _Round(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onTap: onClose,
                    ),
                  ],
                )
              : _Round(
                  icon: Icons.visibility_outlined,
                  tooltip: 'Show card controls',
                  onTap: onExpand,
                ),
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Icon(
                  icon,
                  size: 19,
                  color: Colors.white,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
