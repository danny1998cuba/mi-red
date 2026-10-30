import 'dart:async';
import 'dart:typed_data';

import 'package:mi_red/features/backups/backup_cipher.dart';
import 'package:mi_red/features/backups/backup_documents.dart';
import 'package:mi_red/features/backups/backup_snapshot.dart';

import 'backup_fixture.dart';

const backupWidgetPassword = 'Synthetic password T07';

class FakeBackupCipher implements BackupCipher {
  BackupSnapshot source = syntheticBackup(notifications: false);
  BackupSnapshot? captured;
  int encryptions = 0, decryptions = 0;
  @override
  Future<Uint8List> encrypt(BackupSnapshot snapshot, String password) async {
    encryptions++;
    captured = snapshot;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<BackupSnapshot> decrypt(Uint8List bytes, String password) async {
    decryptions++;
    if (password != backupWidgetPassword) {
      throw const BackupException('Contraseña incorrecta o archivo dañado.');
    }
    return source;
  }
}

class FakeBackupDocuments implements BackupDocuments {
  int saves = 0, picks = 0;
  bool cancelSave = false,
      cancelPick = false,
      failSave = false,
      failPick = false;
  String? lastName;
  Uint8List? saved;
  Completer<void>? saveGate;
  Completer<PickedBackup?>? pickGate;
  @override
  Future<String?> save(Uint8List encrypted, String name) async {
    saves++;
    lastName = name;
    saved = Uint8List.fromList(encrypted);
    if (saveGate != null) await saveGate!.future;
    if (failSave) throw StateError('Synthetic storage/ENOSPC error');
    return cancelSave ? null : '/document/primary:Download/$name';
  }

  @override
  Future<PickedBackup?> pick() async {
    picks++;
    if (pickGate != null) return pickGate!.future;
    if (failPick) throw StateError('Synthetic permission error');
    return cancelPick
        ? null
        : PickedBackup(
            Uint8List.fromList([1, 2, 3]),
            'Copia sintética T07.miredbk',
          );
  }
}
