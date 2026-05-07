import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:dadytube/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('database getter throws when initialization fails', () async {
    // Attempt to force an initialization failure
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'dadytube.db');

    // Create a directory where the DB file should be, causing openDatabase to fail
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    try {
      await expectLater(
        () => DatabaseService.instance.database,
        throwsA(isA<DatabaseException>())
      );
    } finally {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
  });
}
