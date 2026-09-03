import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/features/messages/domain/models/chat_models.dart';
import 'package:flutter_swipes/src/features/messages/presentation/screens/chat_screen.dart';
import 'package:flutter_swipes/src/features/payments/presentation/providers/entitlements_provider.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/message_activation_packages.dart';

/// Cap-style chat popup — blurred backdrop, inset rounded panel (not
/// full-bleed). Dashboard chrome stays visible/blurred around the sheet.
Future<void> showChatPopup(
  BuildContext context, {
  required ChatConversation conversation,
  bool isNewConversation = false,
}) async {
  AppHaptics.selection();

  // Cap `messagingEntitlements.ts` — soft-gate starting NEW threads only.
  if (isNewConversation) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final entitlements = await container.read(
        messagingEntitlementsProvider.future,
      );
      if (!entitlements.canStartConversation) {
        if (!context.mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const MessageActivationPackages(),
        );
        return;
      }
    } catch (_) {
      // Offline-friendly: still open chat if entitlements fail to load.
    }
  }

  if (!context.mounted) return;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close chat',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, anim, secondary) {
      return _ChatPopup(conversation: conversation, anim: anim);
    },
  );
}

class _ChatPopup extends StatelessWidget {
  const _ChatPopup({required this.conversation, required this.anim});

  final ChatConversation conversation;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        // Dark + blur barrier — dashboard design shows through around sheet.
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: const ColoredBox(color: Color(0x99000000)),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: pad.top + 28,
          bottom: pad.bottom + 18,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: anim,
                      curve: const Cubic(0.22, 1, 0.36, 1),
                    ),
                  ),
              child: _ChatPopupPanel(conversation: conversation),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded chat panel with a top grab-handle for drag-to-dismiss, isolated
/// from the message list so it never steals scroll gestures.
class _ChatPopupPanel extends StatefulWidget {
  const _ChatPopupPanel({required this.conversation});

  final ChatConversation conversation;

  @override
  State<_ChatPopupPanel> createState() => _ChatPopupPanelState();
}

class _ChatPopupPanelState extends State<_ChatPopupPanel>
    with SingleTickerProviderStateMixin {
  double _dragY = 0;
  bool _dismissing = false;
  AnimationController? _snapBack;

  static const _dismissThreshold = 70.0;

  @override
  void dispose() {
    _snapBack?.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    setState(() => _dragY = (_dragY + d.delta.dy).clamp(0.0, 260.0));
  }

  void _onDragEnd(DragEndDetails d) {
    if (_dismissing) return;
    final velocity = d.primaryVelocity ?? 0;
    if (_dragY >= _dismissThreshold || velocity > 900) {
      setState(() => _dismissing = true);
      AppHaptics.medium();
      Navigator.of(context).pop();
      return;
    }
    _snapBack?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    final tween = Tween<double>(
      begin: _dragY,
      end: 0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    tween.addListener(() => setState(() => _dragY = tween.value));
    _snapBack = controller;
    controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1 - (_dragY / 260)).clamp(0.4, 1.0);
    return Transform.translate(
      offset: Offset(0, _dragY),
      child: Opacity(
        opacity: opacity,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF5101016),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withAlpha(36)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(160),
                    blurRadius: 40,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.only(top: 10, bottom: 6),
                      color: Colors.transparent,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(70),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ChatScreen(
                      conversation: widget.conversation,
                      onBack: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
