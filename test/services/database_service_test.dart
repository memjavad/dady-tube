import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dadytube/services/database_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('database returns the same instance', () async {
    final db1 = await DatabaseService.instance.database;
    final db2 = await DatabaseService.instance.database;
    expect(identical(db1, db2), isTrue);
  });
}
