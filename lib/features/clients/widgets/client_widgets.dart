import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:forui/forui.dart';

import '../../../core/design_system/app_components.dart';

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
        builder: (context) => AppConfirmDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          cancelLabel: cancelLabel,
          onDecision: (value) => decide(context, value),
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
  Widget build(BuildContext context) => AppStatusBadge(
    icon: switch (status) {
      'active' => FLucideIcons.circleCheck,
      'suspended' => FLucideIcons.circlePause,
      _ => FLucideIcons.archive,
    },
    tone: switch (status) {
      'active' => AppStatusTone.positive,
      'suspended' => AppStatusTone.warning,
      _ => AppStatusTone.neutral,
    },
    label: serviceStatusLabel(status),
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
  Widget build(BuildContext context) => AppEmptyState(
    title: title,
    message: message,
    onAction: onAction,
    actionLabel: actionLabel,
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
      appBar: AppPageHeader(
        context,
        widget.title,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: widget.isSaving ? null : _leave,
          icon: const Icon(FLucideIcons.arrowLeft),
        ),
      ),
      body: SafeArea(child: widget.child),
    ),
  );
}
