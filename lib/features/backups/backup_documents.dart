import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';

import 'backup_cipher.dart';
import 'backup_snapshot.dart';

class PickedBackup {
  const PickedBackup(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

abstract class BackupDocuments {
  Future<String?> save(Uint8List encrypted, String fileName);
  Future<PickedBackup?> pick();
}

class SafBackupDocuments implements BackupDocuments {
  @override
  Future<String?> save(Uint8List encrypted, String fileName) async {
    if (encrypted.length > maxBackupFileBytes) {
      throw const BackupException('La copia supera el tamaño permitido.');
    }
    final cache = await getTemporaryDirectory();
    await cleanBackupCache(cache);
    final temporary = await cache.createTemp('mi_red_backup-');
    try {
      final source = File(
        '${temporary.path}${Platform.pathSeparator}encrypted.miredbk',
      );
      await source.writeAsBytes(encrypted, flush: true);
      // Only the encrypted private source is a dart:io path; the returned
      // destination identifies a SAF document and must never be opened as File.
      return await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: source.path,
          fileName: fileName,
          mimeTypesFilter: const ['application/octet-stream'],
        ),
      );
    } finally {
      await cleanBackupCache(cache);
    }
  }

  @override
  Future<PickedBackup?> pick() async {
    final cache = Directory(
      await (await getTemporaryDirectory()).resolveSymbolicLinks(),
    );
    await cleanBackupCache(cache);
    try {
      final path = await FlutterFileDialog.pickFile(
        params: const OpenFileDialogParams(
          fileExtensionsFilter: ['miredbk'],
          copyFileToCacheDir: true,
        ),
      );
      if (path == null) return null;
      // copyFileToCacheDir is explicitly true: only use the plugin's private copy.
      if (Uri.tryParse(path)?.hasScheme == true) {
        throw const BackupException(
          'El selector no entregó una copia privada legible.',
        );
      }
      final file = File(await File(path).resolveSymbolicLinks());
      if (!file.path.startsWith('${cache.path}${Platform.pathSeparator}')) {
        throw const BackupException(
          'El selector devolvió una ubicación no compatible.',
        );
      }
      if (await file.length() > maxBackupFileBytes) {
        throw const BackupException('La copia supera el límite de 16 MiB.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in file.openRead(0, maxBackupFileBytes + 1)) {
        builder.add(chunk);
        if (builder.length > maxBackupFileBytes) {
          throw const BackupException('La copia supera el límite de 16 MiB.');
        }
      }
      return PickedBackup(builder.takeBytes(), file.uri.pathSegments.last);
    } finally {
      // This includes failed/cancelled plugin copies; never delete public documents.
      await cleanBackupCache(cache);
    }
  }
}

/// Only integration-owned entries in the private app cache; never documents.
/// Also removes encrypted sources left by an interrupted early T07 plugin save.
Future<void> cleanBackupCache(Directory directory) async {
  final cache = Directory(await directory.resolveSymbolicLinks());
  await for (final entry in cache.list(followLinks: false)) {
    final name = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
    final ownedDirectory =
        entry is Directory &&
        (name.startsWith('file_dialog-') || name.startsWith('mi_red_backup-'));
    final legacyEncryptedSource =
        entry is File &&
        RegExp(r'^MiRed-[0-9TZ]+\.miredbk[0-9]+$').hasMatch(name);
    if (!ownedDirectory && !legacyEncryptedSource) {
      continue;
    }
    final resolved = await entry.resolveSymbolicLinks();
    if (!resolved.startsWith('${cache.path}${Platform.pathSeparator}')) {
      continue;
    }
    if (entry is Directory) {
      await entry.delete(recursive: true);
    } else if (entry is File) {
      await entry.delete();
    }
  }
}
