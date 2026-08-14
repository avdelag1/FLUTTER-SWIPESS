import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/legal/data/legal_repository.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/legal_providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cap `LegalVideoCallModal` — ring lawyers, then open Jitsi.
Future<void> showLegalVideoCallModal(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Legal video',
    barrierColor: Colors.black.withAlpha(210),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, _, _) => const _LegalVideoCallBody(),
  );
}

class _LegalVideoCallBody extends ConsumerStatefulWidget {
  const _LegalVideoCallBody();

  @override
  ConsumerState<_LegalVideoCallBody> createState() => _LegalVideoCallBodyState();
}

class _LegalVideoCallBodyState extends ConsumerState<_LegalVideoCallBody> {
  String _phase = 'connecting';
  String? _error;
  LegalVideoCall? _call;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _phase = 'ended';
        _error = 'Sign in to start a live video call with a lawyer.';
      });
      return;
    }
    final name = (user.userMetadata?['full_name'] as String?) ??
        (user.userMetadata?['name'] as String?) ??
        user.email?.split('@').first ??
        'Client';
    try {
      final call = await ref.read(legalRepositoryProvider).startVideoCall(
            clientUserId: user.id,
            clientName: name,
            clientEmail: user.email,
          );
      if (!mounted) return;
      setState(() {
        _call = call;
        _phase = 'ringing';
      });
      AppHaptics.medium();
      Future<void>.delayed(const Duration(seconds: 60), () async {
        if (!mounted || _phase != 'ringing' || _call == null) return;
        await ref
            .read(legalRepositoryProvider)
            .updateVideoCallStatus(_call!.id, 'missed');
        if (mounted) setState(() => _phase = 'ended');
      });
      ref.read(legalRepositoryProvider).watchVideoCall(call.id).listen((row) {
        if (!mounted) return;
        final status = row['status'] as String?;
        if (status == 'accepted') {
          setState(() => _phase = 'live');
          _openRoom(call.roomId, name);
        } else if (status == 'declined' ||
            status == 'ended' ||
            status == 'missed' ||
            status == 'cancelled') {
          setState(() => _phase = 'ended');
        }
      });
    } on LegalVideoException catch (e) {
      setState(() {
        _phase = 'ended';
        _error = e.code == 'NO_LAWYERS_AVAILABLE'
            ? 'No lawyers are available right now. Ask them to turn on Available in the Legal Portal, then try again.'
            : 'Could not start the video call.';
      });
    } catch (_) {
      setState(() {
        _phase = 'ended';
        _error = 'Could not start the video call.';
      });
    }
  }

  Future<void> _openRoom(String roomId, String name) async {
    final url = Uri.parse(LegalRepository.jitsiUrl(roomId, name));
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _hangUp() async {
    final call = _call;
    if (call != null) {
      final status = _phase == 'live' ? 'ended' : 'cancelled';
      try {
        await ref
            .read(legalRepositoryProvider)
            .updateVideoCallStatus(call.id, status);
      } catch (_) {}
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_phase) {
      'connecting' => 'Connecting…',
      'ringing' => 'Ringing available lawyers…',
      'live' => 'Live consultation',
      _ => _error ?? 'Call ended',
    };
    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: const Color(0xFF121218),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF6366F1), width: 1.4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _phase == 'live'
                        ? Icons.videocam_rounded
                        : Icons.balance_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'LEGAL VIDEO',
                  style: AppTheme.displayItalic.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                if (_phase == 'connecting' || _phase == 'ringing') ...[
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    color: Color(0xFF6366F1),
                    strokeWidth: 2,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _hangUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      _phase == 'live' ? 'END CALL' : 'CANCEL',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
