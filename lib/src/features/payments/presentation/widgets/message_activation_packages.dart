import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';

/// Backward-compatible entry point for older screens that still open the
/// former "message activation" sheet. Tokens now mean Direct Requests, so all
/// callers share one clear explanation and one purchase surface.
class MessageActivationPackages extends StatelessWidget {
  const MessageActivationPackages({
    super.key,
    this.userRole = 'client',
    this.onClose,
  });

  final String userRole;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => const TokensModal();
}

Future<void> showMessageActivationPackages(
  BuildContext context, {
  String userRole = 'client',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        const FractionallySizedBox(heightFactor: .9, child: TokensModal()),
  );
}
