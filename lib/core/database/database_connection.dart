import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

QueryExecutor openAppDatabase() => LazyDatabase(() async {
  final directory = await getApplicationSupportDirectory();
  final temporaryPath = (await getTemporaryDirectory()).path;
  await directory.create(recursive: true);
  return NativeDatabase.createInBackground(
    File('${directory.path}${Platform.pathSeparator}mi_red.sqlite'),
    isolateSetup: () => sqlite3.tempDirectory = temporaryPath,
  );
});
