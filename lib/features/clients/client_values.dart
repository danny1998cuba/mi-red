import '../../core/database/app_database.dart';
import 'data/client_service.dart';
import 'data/device_service.dart';

const maxAmountMinor = 9223372036854775807;

int parseMoneyMinor(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(value)) {
    throw const FormatException(
      'Introduce un importe válido con hasta 2 decimales.',
    );
  }
  final parts = value.split(RegExp('[.,]'));
  final minor =
      BigInt.parse(parts.first) * BigInt.from(100) +
      BigInt.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
  if (minor > BigInt.from(maxAmountMinor)) {
    throw const FormatException('El importe supera el máximo permitido.');
  }
  return minor.toInt();
}

String formatMoneyMinor(int amountMinor, {String currencyLabel = ''}) {
  if (amountMinor < 0) throw ArgumentError('El importe no puede ser negativo.');
  final number =
      '${amountMinor ~/ 100},${(amountMinor % 100).toString().padLeft(2, '0')}';
  final label = currencyLabel.trim();
  return label.isEmpty ? number : '$number $label';
}

String? validateMonthlyFee(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'La mensualidad es obligatoria.';
  }
  try {
    parseMoneyMinor(value);
    return null;
  } on FormatException catch (error) {
    return error.message;
  }
}

String? validateClientName(String? value) =>
    value == null || value.trim().isEmpty ? 'El nombre es obligatorio.' : null;

String? validatePhone(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) return null;
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return RegExp(r'^\+?[0-9 ()-]+$').hasMatch(phone) &&
          digits.length >= 6 &&
          digits.length <= 15
      ? null
      : 'Usa de 6 a 15 dígitos; puedes incluir +, espacios, guiones y paréntesis.';
}

String? optionalText(String value) =>
    value.trim().isEmpty ? null : value.trim();

String serviceStatusLabel(String status) => switch (status) {
  'active' => 'Activo',
  'suspended' => 'Suspendido',
  'archived' => 'Archivado',
  _ => 'Estado desconocido',
};

String deviceTypeLabel(DeviceType type) => switch (type) {
  DeviceType.antenna => 'Antena',
  DeviceType.ont => 'ONT',
  DeviceType.router => 'Router',
  DeviceType.other => 'Otro',
};

List<ClientRecord> filterClients(
  List<ClientRecord> clients, {
  required String query,
  required ServiceStatus? status,
}) {
  final search = query.trim().toLowerCase();
  final result = clients
      .where(
        (client) =>
            (status == null || client.status == status.name) &&
            (search.isEmpty ||
                [
                  client.fullName,
                  client.phone ?? '',
                  client.address ?? '',
                ].any((value) => value.toLowerCase().contains(search))),
      )
      .toList();
  result.sort((a, b) {
    final byName = a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    return byName == 0 ? a.id.compareTo(b.id) : byName;
  });
  return result;
}
