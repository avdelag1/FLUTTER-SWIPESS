import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/payments/presentation/screens/tokens_page.dart';

/// Backward-compatible entry point for older screens that still reference the
/// former message-activation purchase surface.
class MessageActivationPackages extends StatelessWidget {
  const MessageActivationPackages({
    super.key,
    this.userRole = 'client',
    this.onClose,
  });

  final String userRole;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => const TokensPage();
}

Future<void> showMessageActivationPackages(
  BuildContext context, {
  String userRole = 'client',
}) => showTokensPage(context);
