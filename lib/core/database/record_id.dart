import 'dart:math';

final _random = Random.secure();

// Stable 128-bit random identifiers, without a dependency on a UUID package.
String newRecordId() => List.generate(
  16,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
