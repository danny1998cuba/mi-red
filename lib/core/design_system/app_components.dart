import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import 'app_design.dart';

Future<bool> validateAppForm(GlobalKey<FormState> form) async {
  final invalid = form.currentState!.validateGranularly();
  if (invalid.isEmpty) return true;
  await WidgetsBinding.instance.endOfFrame;
  if (invalid.first.mounted) {
    await Scrollable.ensureVisible(
      invalid.first.context,
      alignment: 0.1,
      duration: const Duration(milliseconds: 180),
    );
  }
  return false;
}

class AppCopyableValue extends StatelessWidget {
  const AppCopyableValue({
    required this.value,
    required this.label,
    required this.copyKey,
    super.key,
  });
  final String value, label;
  final Key copyKey;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SelectableText('IP: $value'),
        ),
      ),
      IconButton(
        key: copyKey,
        tooltip: 'Copiar $label',
        icon: const Icon(FLucideIcons.copy, size: 18),
        onPressed: () async {
          try {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dirección IP copiada.')),
              );
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No se pudo copiar la dirección IP.'),
                ),
              );
            }
          }
        },
      ),
    ],
  );
}

class AppPageHeader extends StatelessWidget implements PreferredSizeWidget {
  AppPageHeader(
    BuildContext context,
    this.title, {
    this.leading,
    this.actions,
    super.key,
  }) : _height = _measure(context, title, actions?.length ?? 0);
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final double _height;
  static double _measure(BuildContext context, String title, int actionCount) {
    final painter =
        TextPainter(
          text: TextSpan(
            text: title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: (MediaQuery.sizeOf(context).width - 88 - actionCount * 48)
              .clamp(80, double.infinity),
        );
    final height = (painter.height + 24).clamp(64.0, double.infinity);
    painter.dispose();
    return height;
  }

  @override
  Size get preferredSize => Size.fromHeight(_height);
  @override
  Widget build(BuildContext context) => AppBar(
    title: Text(title, softWrap: true, overflow: TextOverflow.visible),
    toolbarHeight: _height,
    leading: leading,
    actions: actions,
  );
}

class AppSection extends StatelessWidget {
  const AppSection(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    ),
  );
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    required this.controller,
    required this.onChanged,
    super.key,
  });
  final TextEditingController controller;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
    onChanged: (_) => onChanged(),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Buscar clientes',
      prefixIcon: const Icon(FLucideIcons.search, size: 18),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Limpiar búsqueda',
              onPressed: () {
                controller.clear();
                onChanged();
              },
              icon: const Icon(FLucideIcons.x, size: 18),
            ),
    ),
  );
}

class AppFilterDisclosure extends StatelessWidget {
  const AppFilterDisclosure({
    required this.expanded,
    required this.summary,
    required this.onPressed,
    required this.child,
    this.controlKey,
    this.action,
    super.key,
  });
  final bool expanded;
  final String summary;
  final VoidCallback onPressed;
  final Widget child;
  final Key? controlKey;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            expanded: expanded,
            child: TextButton.icon(
              key: controlKey,
              onPressed: onPressed,
              icon: const Icon(FLucideIcons.slidersHorizontal, size: 16),
              label: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Filtros · $summary'),
                  Icon(
                    expanded
                        ? FLucideIcons.chevronUp
                        : FLucideIcons.chevronDown,
                    size: 16,
                  ),
                ],
              ),
              iconAlignment: IconAlignment.start,
            ),
          ),
          ?action,
        ],
      ),
      if (expanded)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: child),
    ],
  );
}

enum AppStatusTone { neutral, positive, warning, danger }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    required this.label,
    required this.icon,
    this.tone = AppStatusTone.neutral,
    super.key,
  });
  final String label;
  final IconData icon;
  final AppStatusTone tone;
  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = switch (tone) {
      AppStatusTone.neutral => p.secondary,
      AppStatusTone.positive => p.success,
      AppStatusTone.warning => p.warning,
      AppStatusTone.danger => p.danger,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon = FLucideIcons.inbox,
    super.key,
  });
  final String title;
  final String? message, actionLabel;
  final VoidCallback? onAction;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.of(context).surface,
            border: Border.all(color: AppPalette.of(context).border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 24),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppPalette.of(context).secondary),
              textAlign: TextAlign.center,
            ),
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

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onDecision,
    super.key,
  });
  final String title, message, confirmLabel, cancelLabel;
  final ValueChanged<bool> onDecision;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => onDecision(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => onDecision(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
