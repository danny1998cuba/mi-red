import 'package:flutter_test/flutter_test.dart';
import 'package:mi_red/features/clients/client_values.dart';
import 'package:mi_red/features/clients/data/device_service.dart';

void main() {
  test(
    'Parses decimal text exactly with two minor digits and either separator',
    () {
      for (final example in <String, int>{
        '0': 0,
        '0,00': 0,
        '42': 4200,
        '1250,50': 125050,
        '1250.50': 125050,
        '1250,5': 125050,
        ' 0001.01 ': 101,
        '92233720368547758.07': maxAmountMinor,
      }.entries) {
        expect(parseMoneyMinor(example.key), example.value);
      }
    },
  );
  test('Formatting and parsing round trip without binary money arithmetic', () {
    for (final minor in [
      0,
      1,
      99,
      100,
      125050,
      9007199254740993,
      maxAmountMinor,
    ]) {
      expect(parseMoneyMinor(formatMoneyMinor(minor)), minor);
    }
    expect(
      formatMoneyMinor(125050, currencyLabel: ' unidad '),
      '1250,50 unidad',
    );
    expect(formatMoneyMinor(0), '0,00');
  });
  test('Rejects empty, negative, non-numeric, thousands, overflow and malformed decimals', () {
    for (final value in [
      '',
      ' ',
      '-1',
      'texto',
      '1e3',
      '1,000',
      '1.000,50',
      '1 000',
      '1,234',
      '1..2',
      '+12',
      '12,',
      '.5',
      '92233720368547758.08',
    ]) {
      expect(
        () => parseMoneyMinor(value),
        throwsFormatException,
        reason: value,
      );
      expect(validateMonthlyFee(value), isNotNull);
    }
  });
  test(
    'Names and international presentation validate without assuming a country',
    () {
      expect(validateClientName('   '), isNotNull);
      expect(validateClientName('Cliente de prueba'), isNull);
      for (final phone in ['', '   ', '+000 (000) 000-000', '000000']) {
        expect(validatePhone(phone), isNull);
      }
      for (final phone in [
        '++000000',
        '000',
        '1234567890123456',
        'abc000000',
      ]) {
        expect(validatePhone(phone), isNotNull);
      }
      expect(optionalText(' +000 (000) 000-000 '), '+000 (000) 000-000');
    },
  );
  test('MAC normalizes every supported presentation and rejects invalid hex or length', () {
    for (final value in [
      '02aabbccdd01',
      '02:aa:bb:cc:dd:01',
      '02-aa-bb-cc-dd-01',
    ]) {
      expect(normalizeMacAddress(value), '02:AA:BB:CC:DD:01');
    }
    for (final value in [
      '02:AA:BB:CC:DD:GG',
      '02aabb',
      '02aabbccdd011',
      '02:AA-BB:CC:DD:01',
    ]) {
      expect(() => normalizeMacAddress(value), throwsArgumentError);
    }
    expect(normalizeMacAddress(' '), isNull);
  });
}
