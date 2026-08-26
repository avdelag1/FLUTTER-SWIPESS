import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/matte_surface.dart';
import 'package:flutter_swipes/src/core/routing/app_paths.dart';
import 'package:flutter_swipes/src/core/utils/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/i18n/app_locale.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/core/widgets/ambient_page_background.dart';
import 'package:flutter_swipes/src/core/widgets/brand_buttons.dart';
import 'package:flutter_swipes/src/core/widgets/glass_text_field.dart';
import 'package:flutter_swipes/src/features/documents/presentation/screens/document_vault_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/screens/vap_id_screen.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/client_verification_flow.dart';
import 'package:flutter_swipes/src/features/profile/presentation/widgets/blocked_users_section.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_swipes/src/core/widgets/cap_back_button.dart';

/// Capacitor ClientSecurity / settings nested sections.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key, this.initialTab = 'security'});

  /// security | verification | preferences | language
  final String initialTab;

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  late String _tab;
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _sounds = true;
  bool _haptics = true;
  bool _biometric = false;
  String _lang = 'en';

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _sounds = prefs.getBool('swipe_sounds') ?? true;
      _haptics = prefs.getBool('haptics') ?? true;
      _biometric = prefs.getBool('swipess_biometric_enabled') ?? false;
      _lang = ref.read(appLocaleProvider).code;
    });
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_tab) {
      'verification' => 'VERIFICATION',
      'preferences' => 'PREFERENCES',
      'language' => 'LANGUAGE',
      _ => 'SECURITY PROTOCOL',
    };
    final subtitle = switch (_tab) {
      'verification' => 'Protect your identity and access',
      'preferences' => 'Sounds, haptics & feel',
      'language' => 'Choose your locale',
      _ => 'Protect your identity and access',
    };

    return Scaffold(
      body: AmbientPageBackground(
        fill: true,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Row(
                children: [
                  const CapBackButton(fallbackPath: AppPaths.clientSettings),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTheme.displayItalic.copyWith(fontSize: 22),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            color: MatteSurface.muted(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (_tab == 'security') ..._security(),
              if (_tab == 'verification') ..._verification(context),
              if (_tab == 'preferences') ..._preferences(),
              if (_tab == 'language') ..._language(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _security() {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '—';
    return [
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACCOUNT EMAIL',
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.faint(context),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 6),
            Text(
              email,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.ink(context),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'UPDATE PASSWORD',
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.faint(context),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            GlassTextField(
              controller: _current,
              hint: 'Current password',
              icon: Icons.lock_outline_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 10),
            GlassTextField(
              controller: _next,
              hint: 'New password',
              icon: Icons.lock_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 10),
            GlassTextField(
              controller: _confirm,
              hint: 'Confirm new password',
              icon: Icons.lock_rounded,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            BrandPrimaryButton(
              label: _busy ? 'Saving…' : 'Save password',
              loading: _busy,
              onPressed: _busy ? null : _savePassword,
            ),
            SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.phonelink_lock_rounded,
                color: AppTheme.brandPrimary,
              ),
              title: Text(
                '2FA Protocol',
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.ink(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '2FA & device verification — coming with security keys',
                style: GoogleFonts.plusJakartaSans(
                  color: MatteSurface.muted(context),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const _Panel(child: BlockedUsersSection()),
    ];
  }

  List<Widget> _verification(BuildContext context) {
    return [
      _Panel(
        child: ClientVerificationFlow(
          onComplete: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Documents submitted. Verification is pending review.',
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 14),
      _Panel(
        child: Column(
          children: [
            BrandGhostButton(
              label: 'Open document vault',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DocumentVaultScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            BrandGhostButton(
              label: 'Open PEARL ID',
              onPressed: () {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const VapIdScreen()));
              },
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _preferences() {
    return [
      _Panel(
        child: Column(
          children: [
            _PrefSwitch(
              label: 'Swipe sounds',
              value: _sounds,
              onChanged: (v) async {
                setState(() => _sounds = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('swipe_sounds', v);
              },
            ),
            Divider(height: 1, color: Colors.transparent),
            _PrefSwitch(
              label: 'Haptics',
              value: _haptics,
              onChanged: (v) async {
                setState(() => _haptics = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('haptics', v);
                if (v) AppHaptics.selection();
              },
            ),
            Divider(height: 1, color: Colors.transparent),
            _PrefSwitch(
              label: 'Face ID / biometrics',
              value: _biometric,
              onChanged: (v) async {
                setState(() => _biometric = v);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('swipess_biometric_enabled', v);
                if (v) AppHaptics.selection();
              },
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _language() {
    return [
      _Panel(
        child: Row(
          children: [
            Expanded(
              child: _Lang(
                label: 'EN',
                active: _lang == 'en',
                onTap: () => _setLang('en'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Lang(
                label: 'ES',
                active: _lang == 'es',
                onTap: () => _setLang('es'),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: 12),
      Text(
        'Full Spanish strings ship with the i18n pack — preference is saved now.',
        style: GoogleFonts.plusJakartaSans(
          color: MatteSurface.muted(context),
          fontSize: 12,
        ),
      ),
    ];
  }

  Future<void> _setLang(String code) async {
    setState(() => _lang = code);
    await ref.read(appLocaleProvider.notifier).setCode(code);
    AppHaptics.selection();
  }

  Future<void> _savePassword() async {
    if (_next.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }
    if (_next.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _next.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Password updated')));
        _current.clear();
        _next.clear();
        _confirm.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MatteSurface.ink(context), width: 1.5),
      ),
      child: child,
    );
  }
}

class _PrefSwitch extends StatelessWidget {
  const _PrefSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: MatteSurface.ink(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppTheme.brandPrimary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Lang extends StatelessWidget {
  const _Lang({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFFFF4D00), Color(0xFFEB4898)],
                )
              : null,
          color: active ? null : Colors.white.withAlpha(12),
          border: Border.all(
            color: active ? Colors.transparent : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: MatteSurface.ink(context),
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}
