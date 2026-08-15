import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Secure Access',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Unlock your Swipess vault',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                if (_busy)
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                else
                  TextButton(
                    onPressed: _unlock,
                    child: const Text('TRY AGAIN'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
