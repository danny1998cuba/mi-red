import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/services.dart';

import 'backup_snapshot.dart';

const backupKdfIterations = 250000;
const backupHeaderBytes = 44;
const maxBackupFileBytes = maxBackupPlainBytes + backupHeaderBytes + 16;
const _magic = [77, 73, 82, 69, 68, 66, 75, 0]; // MIREDBK\0

abstract class BackupCipher {
  Future<Uint8List> encrypt(BackupSnapshot snapshot, String password);
  Future<BackupSnapshot> decrypt(Uint8List bytes, String password);
}

class AuthenticatedBackupCipher implements BackupCipher {
  AuthenticatedBackupCipher({
    bool nativeAndroid = false,
    Pbkdf2? keyDerivation,
    AesGcm? cipher,
  }) : _aes =
           cipher ??
           (nativeAndroid
               ? FlutterAesGcm.with256bits()
               : DartAesGcm(secretKeyLength: 32)),
       _kdf =
           keyDerivation ??
           (nativeAndroid
               ? FlutterPbkdf2(
                   macAlgorithm: Hmac.sha256(),
                   bits: 256,
                   iterations: backupKdfIterations,
                 )
               : DartPbkdf2(
                   macAlgorithm: Hmac.sha256(),
                   iterations: backupKdfIterations,
                   bits: 256,
                 ));
  final AesGcm _aes;
  final Pbkdf2 _kdf;

  Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    try {
      return await _kdf.deriveKeyFromPassword(password: password, nonce: salt);
    } on PlatformException catch (error) {
      if (error.code != 'UNSUPPORTED_ALGORITHM') {
        rethrow;
      }
      // Android supplies PBKDF2-SHA256 from API 26. Keep API 24/25 portable
      // with the identical library algorithm and cost in a background isolate.
    } on MissingPluginException {
      // No change of format, cipher or KDF parameters when native APIs are absent.
    }
    return BackgroundPbkdf2(
      macAlgorithm: Hmac.sha256(),
      bits: 256,
      iterations: backupKdfIterations,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  @override
  Future<Uint8List> encrypt(BackupSnapshot snapshot, String password) async {
    validateBackupPassword(password);
    final random = Random.secure();
    final header = Uint8List(backupHeaderBytes)..setRange(0, 8, _magic);
    final data = ByteData.sublistView(header);
    data.setUint32(8, backupFormatVersion);
    data.setUint32(12, backupKdfIterations);
    for (var i = 16; i < header.length; i++) {
      header[i] = random.nextInt(256);
    }
    final plain = snapshot.encode();
    SecretKey? key;
    try {
      key = await _deriveKey(password, header.sublist(16, 32));
      final box = await _aes.encrypt(
        plain,
        secretKey: key,
        nonce: header.sublist(32, 44),
        aad: header,
      );
      return Uint8List.fromList([
        ...header,
        ...box.cipherText,
        ...box.mac.bytes,
      ]);
    } finally {
      plain.fillRange(0, plain.length, 0);
      key?.destroy();
    }
  }

  @override
  Future<BackupSnapshot> decrypt(Uint8List bytes, String password) async {
    if (bytes.length <= backupHeaderBytes + 16 ||
        bytes.length > maxBackupFileBytes) {
      throw const BackupException(
        'Archivo vacío, incompleto o mayor que el límite de 16 MiB.',
      );
    }
    final header = bytes.sublist(0, backupHeaderBytes);
    final data = ByteData.sublistView(header);
    if (List.generate(8, (i) => header[i] == _magic[i]).contains(false) ||
        data.getUint32(8) != backupFormatVersion ||
        data.getUint32(12) != backupKdfIterations) {
      throw const BackupException(
        'Encabezado o versión de archivo incompatible.',
      );
    }
    // Version 1 fixes the KDF cost, so an untrusted header cannot demand unbounded work.
    validateBackupPassword(password, importing: true);
    final key = await _deriveKey(password, header.sublist(16, 32));
    Uint8List? plain;
    try {
      // Platform channels may return a read-only view. Only wipe a buffer we own.
      plain = Uint8List.fromList(
        await _aes.decrypt(
          SecretBox(
            bytes.sublist(backupHeaderBytes, bytes.length - 16),
            nonce: header.sublist(32, 44),
            mac: Mac(bytes.sublist(bytes.length - 16)),
          ),
          secretKey: key,
          aad: header,
        ),
      );
      return BackupSnapshot.decode(plain);
    } on SecretBoxAuthenticationError {
      throw const BackupException(
        'No se pudo autenticar la copia: contraseña incorrecta o archivo dañado. No se cambió ningún dato.',
      );
    } finally {
      if (plain != null) plain.fillRange(0, plain.length, 0);
      key.destroy();
    }
  }
}

void validateBackupPassword(String password, {bool importing = false}) {
  if (password.length > 1024 ||
      password.trim().isEmpty ||
      (!importing && password.runes.length < 12)) {
    throw BackupException(
      importing
          ? 'Introduce la contraseña de la copia (máximo 1024 caracteres).'
          : 'Usa una contraseña de al menos 12 caracteres y como máximo 1024. No se puede recuperar si la olvidas.',
    );
  }
}
