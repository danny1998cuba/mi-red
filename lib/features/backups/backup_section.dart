import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../core/database/database_maintenance.dart';
import '../../core/design_system/app_components.dart';
import '../../core/design_system/app_design.dart';
import '../../core/navigation/app_router.dart';
import '../billing/billing_providers.dart';
import '../billing/billing_values.dart';
import '../clients/client_providers.dart';
import '../reminders/reminder_providers.dart';
import 'backup_cipher.dart';
import 'backup_providers.dart';
import 'backup_snapshot.dart';

class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({this.showHeading = true, super.key});
  final bool showHeading;
  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
  bool _opening = false;
  String? _notice;

  Future<void> _open(bool importing) async {
    if (_opening) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _opening = true;
      _notice = null;
    });
    final maintenance = ref.read(databaseMaintenanceProvider);
    var restored = false;
    var acquired = false;
    try {
      maintenance.begin();
      acquired = true;
      // Drain writes already in flight before presenting the exclusive modal.
      try {
        await ref.read(billingSessionProvider.future);
      } catch (_) {
        /* A restore remains available after a reconciliation error. */
      }
      await ref.read(remindersProvider.notifier).settle();
      if (!mounted) return;
      final notice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _BackupDialog(
          importing: importing,
          onRestored: () => restored = true,
        ),
      );
      if (mounted && notice != null) setState(() => _notice = notice);
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'No se pudo iniciar la operación. Puedes volver a intentarlo.',
        );
      }
    } finally {
      if (acquired) maintenance.end();
      if (mounted) {
        setState(() => _opening = false);
        if (restored) ref.read(appRouterProvider).go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.showHeading) const AppSection('Copias de seguridad'),
      FCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Copia completa y cifrada de clientes, equipos, mensualidades, pagos y ajustes. La contraseña no se puede recuperar.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Elige un documento fuera de Mi Red y conserva otra copia fuera del teléfono. Una única copia en el mismo equipo no protege frente a su pérdida.',
              ),
              const SizedBox(height: 12),
              ref
                  .watch(lastBackupProvider)
                  .when(
                    data: (value) => Text(
                      value == null
                          ? 'Última copia: todavía no registrada.'
                          : 'Última copia: ${paymentDateLabel(value)}',
                    ),
                    loading: () => const Text('Consultando última copia…'),
                    error: (_, _) => const Text(
                      'No se pudo consultar la fecha de la última copia.',
                    ),
                  ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('backup-create'),
                    onPressed: _opening ? null : () => _open(false),
                    icon: const Icon(FLucideIcons.download, size: 18),
                    label: const Text('Crear copia'),
                  ),
                  OutlinedButton.icon(
                    key: const Key('backup-restore'),
                    onPressed: _opening ? null : () => _open(true),
                    icon: const Icon(FLucideIcons.upload, size: 18),
                    label: const Text('Restaurar copia'),
                  ),
                ],
              ),
              if (_opening)
                const LinearProgressIndicator(
                  semanticsLabel: 'Operación de copia en curso',
                ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(liveRegion: true, child: Text(_notice!)),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _BackupDialog extends ConsumerStatefulWidget {
  const _BackupDialog({required this.importing, required this.onRestored});
  final bool importing;
  final VoidCallback onRestored;
  @override
  ConsumerState<_BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends ConsumerState<_BackupDialog> {
  final _password = TextEditingController(),
      _confirmation = TextEditingController();
  final _feedbackKey = GlobalKey();
  Uint8List? _encrypted;
  BackupSnapshot? _snapshot;
  Map<String, int>? _currentCounts;
  String? _fileName, _error, _complete;
  bool _busy = false, _visible = false, _accepted = false, _restored = false;

  @override
  void initState() {
    super.initState();
    if (widget.importing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pick();
      });
    }
  }

  @override
  void dispose() {
    _clearPasswords();
    _password.dispose();
    _confirmation.dispose();
    _encrypted?.fillRange(0, _encrypted!.length, 0);
    _snapshot = null;
    super.dispose();
  }

  void _clearPasswords() {
    _password.clear();
    _confirmation.clear();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      _clearPasswords();
      if (mounted) {
        setState(
          () => _error = error is BackupException ? error.message : 'No se pudo completar la operación. Revisa el archivo, el permiso del documento y el espacio disponible. Puedes reintentar; no se informó éxito.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && _feedbackKey.currentContext != null) {
          await Scrollable.ensureVisible(
            _feedbackKey.currentContext!,
            alignment: 1,
            duration: const Duration(milliseconds: 180),
          );
        }
      }
    }
  }

  Future<void> _pick() => _run(() async {
    _clearPasswords();
    _encrypted?.fillRange(0, _encrypted!.length, 0);
    _encrypted = null;
    _fileName = null;
    _snapshot = null;
    _currentCounts = null;
    _accepted = false;
    final picked = await ref.read(backupDocumentsProvider).pick();
    if (!mounted) return;
    if (picked == null) {
      Navigator.pop(
        context,
        'Selección de copia cancelada. No se reemplazó ningún dato.',
      );
    } else {
      setState(() {
        _encrypted = picked.bytes;
        _fileName = picked.name;
      });
    }
  });

  Future<void> _export() => _run(() async {
    validateBackupPassword(_password.text);
    if (_password.text != _confirmation.text) {
      throw const BackupException(
        'Las contraseñas no coinciden. Vuelve a introducirlas.',
      );
    }
    var password = _password.text;
    _clearPasswords();
    final now = ref.read(clientClockProvider)();
    final snapshot = await ref.read(backupServiceProvider).capture(now);
    Uint8List? encrypted;
    try {
      encrypted = await ref
          .read(backupCipherProvider)
          .encrypt(snapshot, password);
      password = '';
      final stamp = snapshot.createdAtUtc.toIso8601String().replaceAll(
        RegExp('[-:.]'),
        '',
      );
      final name = 'MiRed-$stamp.miredbk';
      final destination = await ref
          .read(backupDocumentsProvider)
          .save(encrypted, name);
      if (!mounted) return;
      if (destination == null) {
        setState(
          () => _error = 'Guardado cancelado. No se confirmó ninguna copia externa; vuelve a introducir la contraseña para reintentar.',
        );
        return;
      }
      if (destination.isEmpty) {
        throw const BackupException(
          'El selector no confirmó un documento guardado.',
        );
      }
      var dateWarning = '';
      try {
        await ref.read(backupServiceProvider).markExported(now);
      } catch (_) {
        dateWarning = '\nEl archivo se guardó, pero no se pudo registrar la fecha en Ajustes.';
      }
      if (mounted) {
        setState(
          () => _complete =
              'Copia cifrada guardada.\n$name\nFecha: ${paymentDateLabel(now.millisecondsSinceEpoch)}\nDestino elegido (SAF): $destination\nConserva otra copia fuera del teléfono.$dateWarning',
        );
      }
    } finally {
      password = '';
      encrypted?.fillRange(0, encrypted.length, 0);
    }
  });

  Future<void> _verify() => _run(() async {
    var password = _password.text;
    _clearPasswords();
    try {
      final snapshot = await ref
          .read(backupCipherProvider)
          .decrypt(_encrypted!, password);
      password = '';
      final counts = await ref.read(backupServiceProvider).counts();
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _currentCounts = counts;
          _accepted = false;
        });
      }
    } finally {
      password = '';
    }
  });

  Future<void> _replace() => _run(() async {
    if (!_accepted || _snapshot == null || _restored) return;
    final warning = await ref.read(backupRestorerProvider)(_snapshot!);
    widget.onRestored();
    _restored = true;
    _snapshot = null;
    _encrypted?.fillRange(0, _encrypted!.length, 0);
    _encrypted = null;
    if (mounted) {
      setState(
        () => _complete = warning ?? 'Datos restaurados y verificados. Los avisos respetan el permiso de este dispositivo. Al volver a Inicio se conciliarán los períodos mediante las reglas existentes.',
      );
    }
  });

  Widget _passwordField(
    TextEditingController controller,
    String key,
    String label,
  ) => TextField(
    key: Key(key),
    controller: controller,
    enabled: !_busy,
    obscureText: !_visible,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    autofillHints: const [],
    keyboardType: TextInputType.visiblePassword,
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: IconButton(
        key: Key('$key-visibility'),
        tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
        onPressed: _busy ? null : () => setState(() => _visible = !_visible),
        icon: Icon(_visible ? FLucideIcons.eyeOff : FLucideIcons.eye, size: 18),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !_busy,
    child: Dialog.fullscreen(
      child: Scaffold(
        appBar: AppPageHeader(
          context,
          widget.importing ? 'Restaurar' : 'Copia nueva',
          leading: IconButton(
            key: const Key('backup-close'),
            tooltip: 'Cerrar',
            icon: const Icon(FLucideIcons.x),
            onPressed: _busy ? null : () => Navigator.pop(context, _complete),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.page),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_complete == null) ...[
                  const Text(
                    'Archivo protegido con contraseña. Si la olvidas, no podrás recuperar esta copia. Mi Red no guarda la contraseña ni ofrece recuperación.',
                  ),
                  const SizedBox(height: 16),
                  if (widget.importing) ...[
                    if (_fileName != null)
                      Text('Archivo seleccionado: $_fileName'),
                    if (_snapshot == null && _encrypted != null) ...[
                      const SizedBox(height: 16),
                      _passwordField(
                        _password,
                        'backup-password',
                        'Contraseña de la copia',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('backup-verify'),
                        onPressed: _busy ? null : _verify,
                        child: const Text('Comprobar copia'),
                      ),
                    ],
                    if (_snapshot != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Copia autenticada · Formato 1 · Esquema ${_snapshot!.sourceSchemaVersion}\nCreada: ${paymentDateLabel(_snapshot!.createdAtUtc.millisecondsSinceEpoch)}',
                      ),
                      const SizedBox(height: 12),
                      const Text('Contenido de la copia / datos actuales'),
                      for (final (table, label) in const [
                        ('clients', 'Clientes'),
                        ('devices', 'Dispositivos'),
                        ('charges', 'Mensualidades'),
                        ('payments', 'Pagos (incluidos anulados)'),
                      ])
                        Text(
                          '$label: ${_snapshot!.counts[table]} / ${_currentCounts![table]}',
                        ),
                      const Text(
                        'Incluye todos los ajustes, MAC, IP y auditoría. No incluye permisos ni alarmas Android.',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Se reemplazarán TODOS los datos actuales por los de esta copia. No se combinarán bases. Las mensualidades posteriores a la copia se conciliarán al volver a Inicio; no se reescriben pagos históricos.',
                      ),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          key: const Key('backup-accept-replacement'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Entiendo que se reemplazarán mis datos actuales',
                          ),
                          value: _accepted,
                          onChanged: _busy
                              ? null
                              : (value) =>
                                    setState(() => _accepted = value ?? false),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('backup-replace'),
                        onPressed: _busy || !_accepted ? null : _replace,
                        child: const Text('Reemplazar datos'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      key: const Key('backup-pick'),
                      onPressed: _busy ? null : _pick,
                      child: Text(
                        _encrypted == null
                            ? 'Seleccionar archivo .miredbk'
                            : 'Elegir otro archivo',
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Usa al menos 12 caracteres. El archivo incluirá todos los datos de la app. Guárdalo en un documento y conserva otra copia fuera del teléfono.',
                    ),
                    const SizedBox(height: 16),
                    _passwordField(
                      _password,
                      'backup-password',
                      'Contraseña de respaldo',
                    ),
                    const SizedBox(height: 16),
                    _passwordField(
                      _confirmation,
                      'backup-confirm-password',
                      'Confirmar contraseña',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('backup-save'),
                      onPressed: _busy ? null : _export,
                      icon: const Icon(FLucideIcons.lockKeyhole, size: 18),
                      label: const Text('Cifrar y elegir destino'),
                    ),
                  ],
                ],
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Comprobando copia; espera a que termine',
                    ),
                  ),
                if (_error != null || _complete != null)
                  Padding(
                    key: _feedbackKey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error ?? _complete!,
                        style: TextStyle(
                          color: _error == null
                              ? null
                              : AppPalette.of(context).danger,
                        ),
                      ),
                    ),
                  ),
                if (_complete != null)
                  FilledButton(
                    key: const Key('backup-done'),
                    onPressed: _busy
                        ? null
                        : () => Navigator.pop(context, _complete),
                    child: Text(_restored ? 'Volver a Inicio' : 'Cerrar'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
