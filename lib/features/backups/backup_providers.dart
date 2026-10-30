import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../billing/billing_providers.dart';
import '../clients/client_providers.dart';
import '../dashboard/dashboard_providers.dart';
import '../reminders/reminder_providers.dart';
import 'backup_cipher.dart';
import 'backup_documents.dart';
import 'backup_service.dart';
import 'backup_snapshot.dart';

final backupServiceProvider = Provider(
  (ref) => BackupService(ref.watch(databaseProvider)),
);
final backupCipherProvider = Provider<BackupCipher>(
  (ref) => AuthenticatedBackupCipher(nativeAndroid: Platform.isAndroid),
);
final backupDocumentsProvider = Provider<BackupDocuments>(
  (ref) => SafBackupDocuments(),
);
final lastBackupProvider = StreamProvider<int?>(
  (ref) =>
      ref.watch(settingsServiceProvider).watch().map((row) => row.lastBackupAt),
);

/// Commit and post-commit effects are separate: an OS error cannot undo a restore.
final backupRestorerProvider =
    Provider<Future<String?> Function(BackupSnapshot)>(
      (ref) => (snapshot) async {
        await ref.read(backupServiceProvider).restore(snapshot);
        String? warning;
        try {
          await ref.read(remindersProvider.notifier).rebuildAfterRestore();
          if (ref.read(remindersProvider).hasError) {
            throw StateError('Reminder rebuild failed');
          }
        } catch (_) {
          warning = 'Los datos se restauraron. No se pudieron preparar los recordatorios; revisa Ajustes. No se revirtió la restauración.';
        }
        // The next financial view reconciles through the existing T02/T04 barrier.
        ref.invalidate(billingSessionProvider);
        ref.invalidate(clientsProvider);
        ref.invalidate(clientProvider);
        ref.invalidate(devicesProvider);
        ref.invalidate(currencyLabelProvider);
        ref.invalidate(dashboardProvider);
        return warning;
      },
    );
