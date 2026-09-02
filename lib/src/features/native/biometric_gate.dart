import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/core/widgets/swipess_controls.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cap `BiometricGate` — native lock after onboarding; web always unlocks.
class BiometricGate extends ConsumerStatefulWidget {
  const BiometricGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate> {
  bool _locked = false;
  bool _ready = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (kIsWeb) {
      setState(() {
        _locked = false;
        _ready = true;
      });
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('swipess_biometric_enabled') ?? false;
      if (!enabled) {
        setState(() {
          _locked = false;
          _ready = true;
        });
        return;
      }
      final auth = LocalAuthentication();
      final can =
          await auth.isDeviceSupported() && await auth.canCheckBiometrics;
      if (!can) {
        setState(() {
          _locked = false;
          _ready = true;
        });
        return;
      }
      setState(() {
        _locked = true;
        _ready = true;
      });
      await _unlock();
    } catch (_) {
      if (mounted) {
        setState(() {
          _locked = false;
          _ready = true;
        });
      }
    }
  }

  Future<void> _unlock() async {
    setState(() => _busy = true);
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Authenticate to access Swipess',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (ok && mounted) setState(() => _locked = false);
    } catch (_) {
      // Stay locked; user can retry.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || !_locked) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        ColoredBox(
          color: Colors.black,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: SwipessTokens.brandPink.withAlpha(24),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: SwipessTokens.brandPink.withAlpha(55),
                        ),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: SwipessTokens.brandPink,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Secure Access',
                      textAlign: TextAlign.center,
                      style: SwipessTokens.displayItalic(
                        color: Colors.white,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unlock your Swipess vault',
                      textAlign: TextAlign.center,
                      style: SwipessTokens.bodyClean(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SwipessButton(
                      label: _busy ? 'Unlocking' : 'Try again',
                      onPressed: _busy ? null : _unlock,
                      loading: _busy,
                      accentColor: SwipessTokens.brandPink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
