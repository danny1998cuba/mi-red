import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../client_values.dart';

Future<bool> confirmClientAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
}) async {
  var decided = false;
  void decide(BuildContext dialogContext, bool value) {
    if (decided) return;
    decided = true;
    Navigator.pop(dialogContext, value);
  }

  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => decide(context, false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => decide(context, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

void backToClients(BuildContext context, [String fallback = '/clients']) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

class ServiceStatusBadge extends StatelessWidget {
  const ServiceStatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(switch (status) {
      'active' => Icons.check_circle_outline,
      'suspended' => Icons.pause_circle_outline,
      _ => Icons.archive_outlined,
    }, size: 18),
    label: Text(serviceStatusLabel(status)),
  );
}

class ClientNotice extends StatelessWidget {
  const ClientNotice({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.people_outline, size: 28),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(message!, textAlign: TextAlign.center),
          ),
        if (onAction != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel ?? 'Reintentar'),
            ),
          ),
      ],
    ),
  );
}

class GuardedFormPage extends StatefulWidget {
  const GuardedFormPage({
    required this.title,
    required this.hasChanges,
    required this.isSaving,
    required this.child,
    required this.fallback,
    super.key,
  });
  final String title;
  final bool hasChanges;
  final bool isSaving;
  final Widget child;
  final String fallback;
  @override
  State<GuardedFormPage> createState() => _GuardedFormPageState();
}

class _GuardedFormPageState extends State<GuardedFormPage> {
  bool _leaving = false;
  bool _asking = false;
  Future<void> _leave() async {
    if (_asking || widget.isSaving) return;
    _asking = true;
    final discard =
        !widget.hasChanges ||
        await confirmClientAction(
          context,
          title: '¿Descartar cambios?',
          message: 'Los cambios sin guardar se perderán.',
          confirmLabel: 'Descartar cambios',
          cancelLabel: 'Seguir editando',
        );
    _asking = false;
    if (!mounted || !discard) return;
    setState(() => _leaving = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) backToClients(context, widget.fallback);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: _leaving || (!widget.hasChanges && !widget.isSaving),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: widget.isSaving ? null : _leave,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(child: widget.child),
    ),
  );
}
