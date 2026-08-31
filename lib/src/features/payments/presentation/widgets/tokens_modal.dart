import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/core/theme/swipess_design_tokens.dart';
import 'package:flutter_swipes/src/features/payments/presentation/screens/tokens_page.dart';

/// Compatibility shim for legacy callers that still request the former token
/// bottom sheet. Tokens now use one opaque full-screen purchase surface.
///
/// The legacy modal is immediately dismissed, then the same root navigator
/// opens [TokensPage]. This prevents any old entry point from leaving a frosted
/// or transparent token sheet in front of app content.
class TokensModal extends StatefulWidget {
  const TokensModal({super.key});

  @override
  State<TokensModal> createState() => _TokensModalState();
}

class _TokensModalState extends State<TokensModal> {
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    if (_redirecting || !mounted) return;
    _redirecting = true;

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final localNavigator = Navigator.of(context);
    if (localNavigator.canPop()) {
      localNavigator.pop();
    }

    await Future<void>.delayed(Duration.zero);
    if (!rootNavigator.mounted) return;

    await rootNavigator.push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const TokensPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: SwipessTokens.darkCanvas,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
