const maxBusinessNameLength = 120;
const maxCurrencyLabelLength = 48;

bool _hasControlCharacters(String text) =>
    text.runes.any((value) => value < 32 || value == 127);

String? validateBusinessName(String? input) {
  final value = input?.trim() ?? '';
  if (value.isEmpty) return 'El nombre del negocio es obligatorio.';
  if (value.runes.length > maxBusinessNameLength ||
      _hasControlCharacters(value)) {
    return 'Usa hasta 120 caracteres en una sola línea.';
  }
  return null;
}

String? validateCurrencyLabel(String? input) {
  final value = input?.trim() ?? '';
  if (value.runes.length > maxCurrencyLabelLength ||
      _hasControlCharacters(value)) {
    return 'Usa hasta 48 caracteres en una sola línea.';
  }
  return null;
}

String? validateCallingCode(String? input) {
  final value = input?.trim() ?? '';
  return value.isEmpty || RegExp(r'^\+[1-9][0-9]{0,2}$').hasMatch(value)
      ? null
      : 'Usa + y de 1 a 3 dígitos, sin cero inicial; por ejemplo +53.';
}
