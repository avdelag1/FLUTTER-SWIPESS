import 'package:flutter/material.dart';
import 'package:flutter_swipes/src/features/payments/presentation/widgets/tokens_modal.dart';

/// Backward-compatible entry point for legacy callers.
///
/// The marketplace no longer sells unrestricted "message activations".
/// This surface now delegates to the single Direct Requests purchase UI so
/// every entry point explains the same consent-first token rule.
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
    builder: (_) => const FractionallySizedBox(
      heightFactor: .9,
      child: TokensModal(),
    ),
  );
}
