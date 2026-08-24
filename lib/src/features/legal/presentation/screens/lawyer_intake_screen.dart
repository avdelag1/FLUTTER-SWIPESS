import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_swipes/src/core/theme/app_theme.dart';
import 'package:flutter_swipes/src/features/legal/domain/lawyer_workspace.dart';
import 'package:flutter_swipes/src/features/legal/presentation/providers/lawyer_workspace_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class LawyerIntakeScreen extends ConsumerStatefulWidget {
  const LawyerIntakeScreen({super.key});

  @override
  ConsumerState<LawyerIntakeScreen> createState() => _LawyerIntakeScreenState();
}

class _LawyerIntakeScreenState extends ConsumerState<LawyerIntakeScreen> {
  String? _workingId;
  String? _error;

  Future<void> _refresh() async {
    ref.invalidate(lawyerWorkspaceProvider);
    await ref.read(lawyerWorkspaceProvider.future);
  }

  Future<void> _offer(Map<String, dynamic> request) async {
    final packages = await ref
        .read(lawyerWorkspaceRepositoryProvider)
        .fetchServicePackages();
    if (!mounted) return;

    String? selectedId = request['package_id']?.toString();
    if (selectedId != null &&
        !packages.any((item) => item['id']?.toString() == selectedId)) {
      selectedId = null;
    }
    final notes = TextEditingController();
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SEND OFFER',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      request['full_name']?.toString() ?? 'Legal request',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: selectedId,
                      decoration: const InputDecoration(
                        labelText: 'Legal package',
                      ),
                      items: [
                        for (final item in packages)
                          DropdownMenuItem(
                            value: item['id']?.toString(),
                            child: Text(
                              '${item['name'] ?? 'Package'} · ${_money(item['price'])}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) =>
                          setSheetState(() => selectedId = value),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: notes,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notes for the client (optional)',
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: selectedId == null
                            ? null
                            : () => Navigator.pop(sheetContext, true),
                        child: const Text('SEND OFFER'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final noteText = notes.text.trim();
    notes.dispose();
    if (accepted != true || selectedId == null) return;

    await _run(
      request['id']?.toString(),
      () => ref.read(lawyerWorkspaceRepositoryProvider).offerIntake(
            requestId: request['id'].toString(),
            packageId: selectedId,
            notes: noteText,
          ),
      success: 'Offer sent. The client can pay before scheduling.',
    );
  }

  Future<void> _decline(Map<String, dynamic> request) async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline this assigned request?'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (accepted != true) return;
    await _run(
      request['id']?.toString(),
      () => ref.read(lawyerWorkspaceRepositoryProvider).declineIntake(
            requestId: request['id'].toString(),
            reason: reason,
          ),
      success: 'Request declined.',
    );
  }

  Future<void> _schedule(Map<String, dynamic> request) async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 1, now.month, now.day),
      initialDate: now.add(const Duration(days: 1)),
    );
    if (!mounted || day == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (!mounted || time == null) return;
    final consultAt = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    await _run(
      request['id']?.toString(),
      () => ref.read(lawyerWorkspaceRepositoryProvider).scheduleConsult(
            requestId: request['id'].toString(),
            consultAt: consultAt,
          ),
      success: 'Consultation scheduled.',
    );
  }

  Future<void> _workflow(
    Map<String, dynamic> request,
    String status,
    String success,
  ) async {
    await _run(
      request['id']?.toString(),
      () async {
        final updated = await ref
            .read(lawyerWorkspaceRepositoryProvider)
            .updateWorkflow(
              requestId: request['id'].toString(),
              status: status,
            );
        if (!updated) throw StateError('Request was not updated');
      },
      success: success,
    );
  }

  Future<void> _run(
    String? id,
    Future<void> Function() action, {
    required String success,
  }) async {
    if (id == null || id.isEmpty || _workingId != null) return;
    setState(() {
      _workingId = id;
      _error = null;
    });
    try {
      await action();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _workingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(lawyerWorkspaceProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Scaffold(
      backgroundColor: AppTheme.canvasFor(isLight: isLight),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Legal intake'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _workingId == null ? _refresh : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: _friendlyError(error),
          onRetry: _refresh,
        ),
        data: (data) => data == null
            ? const _ErrorState(message: 'Lawyer workspace is not active.')
            : _content(data, isLight),
      ),
    );
  }

  Widget _content(LawyerWorkspace workspace, bool isLight) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          if (_error != null) ...[
            _Notice(message: _error!, isError: true),
            const SizedBox(height: 12),
          ],
          _HeaderMetric(
            label: 'AVAILABLE TO CLAIM',
            value: workspace.availableRequests,
            icon: Icons.inbox_rounded,
            isLight: isLight,
          ),
          const SizedBox(height: 14),
          _section('NEW REQUESTS'),
          const SizedBox(height: 8),
          if (workspace.availableQueue.isEmpty)
            const _Notice(message: 'No unassigned requests right now.')
          else
            for (final request in workspace.availableQueue) ...[
              _RequestCard(
                request: request,
                isLight: isLight,
                working: _workingId == request['id']?.toString(),
                actions: [
                  _Action(
                    label: 'Review & offer',
                    icon: Icons.send_rounded,
                    onTap: () => _offer(request),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          const SizedBox(height: 18),
          _section('MY REQUESTS'),
          const SizedBox(height: 8),
          if (workspace.requests.isEmpty)
            const _Notice(message: 'No assigned requests yet.')
          else
            for (final request in workspace.requests) ...[
              _assignedCard(request, isLight),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _assignedCard(Map<String, dynamic> request, bool isLight) {
    final status = request['status']?.toString().toLowerCase() ?? 'pending';
    final actions = <_Action>[];
    if (status == 'pending' || status == 'offered') {
      actions.add(
        _Action(
          label: status == 'offered' ? 'Update offer' : 'Send offer',
          icon: Icons.send_rounded,
          onTap: () => _offer(request),
        ),
      );
      actions.add(
        _Action(
          label: 'Decline',
          icon: Icons.close_rounded,
          onTap: () => _decline(request),
        ),
      );
    } else if (status == 'paid') {
      actions.add(
        _Action(
          label: 'Schedule consult',
          icon: Icons.calendar_month_rounded,
          onTap: () => _schedule(request),
        ),
      );
    } else if (status == 'scheduled') {
      actions.add(
        _Action(
          label: 'Start work',
          icon: Icons.play_arrow_rounded,
          onTap: () => _workflow(request, 'in_progress', 'Work started.'),
        ),
      );
    } else if (status == 'in_progress' || status == 'reviewing') {
      actions.add(
        _Action(
          label: 'Complete',
          icon: Icons.check_rounded,
          onTap: () => _workflow(request, 'completed', 'Request completed.'),
        ),
      );
    }

    return _RequestCard(
      request: request,
      isLight: isLight,
      working: _workingId == request['id']?.toString(),
      actions: actions,
    );
  }

  static Widget _section(String text) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      );

  static String _money(Object? raw) {
    final value = (raw as num?)?.toDouble();
    if (value == null) return 'Price TBD';
    return NumberFormat.currency(symbol: r'$', decimalDigits: 0).format(value);
  }

  static String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('already assigned')) {
      return 'Another lawyer already claimed this request.';
    }
    if (text.contains('Active lawyer')) {
      return 'Your Lawyer workspace is not active.';
    }
    if (text.contains('paid')) {
      return 'The client must complete payment before scheduling.';
    }
    return 'Could not update this legal request. Refresh and try again.';
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isLight,
    required this.working,
    required this.actions,
  });

  final Map<String, dynamic> request;
  final bool isLight;
  final bool working;
  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'pending';
    final situation = request['situation']?.toString().trim();
    final created = DateTime.tryParse(request['created_at']?.toString() ?? '');
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : AppTheme.dashGlassStrong,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLight
              ? Colors.black.withAlpha(18)
              : Colors.white.withAlpha(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request['package_name']?.toString() ?? 'Legal request',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            [
              request['full_name']?.toString(),
              request['city']?.toString(),
              LawyerIntakeScreenStateMoney.money(request['quoted_price']),
            ].whereType<String>().where((value) => value.isNotEmpty).join(' · '),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (situation != null && situation.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              situation,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ],
          if (created != null) ...[
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM d, h:mm a').format(created.toLocal()),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (working)
              const LinearProgressIndicator(minHeight: 2)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final action in actions)
                    OutlinedButton.icon(
                      onPressed: action.onTap,
                      icon: Icon(action.icon, size: 16),
                      label: Text(action.label),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class LawyerIntakeScreenStateMoney {
  static String money(Object? raw) {
    final value = (raw as num?)?.toDouble();
    if (value == null) return '';
    return NumberFormat.currency(symbol: r'$', decimalDigits: 0).format(value);
  }
}

class _Action {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.isLight,
  });

  final String label;
  final int value;
  final IconData icon;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : AppTheme.dashGlassStrong,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? Colors.redAccent.withAlpha(18)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gavel_rounded, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => onRetry!(),
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
