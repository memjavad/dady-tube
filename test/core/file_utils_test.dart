import 'dart:io';
import 'package:test/test.dart';
import 'package:dadytube/core/file_utils.dart';

void main() {
  test('FileUtils.isFileReady checks existence and length correctly', () async {
    final tempDir = await Directory.systemTemp.createTemp('file_utils_test_');
    try {
      // 1. Missing file
      final missingPath = '${tempDir.path}/missing.mp4';
      final missingFile = File(missingPath);
      expect(await FileUtils.isFileReady(missingFile), false);

      // 2. Empty file
      final emptyPath = '${tempDir.path}/empty.mp4';
      final emptyFile = File(emptyPath);
      await emptyFile.create();
      expect(await FileUtils.isFileReady(emptyFile), false);

      // 3. Valid file
      final validPath = '${tempDir.path}/valid.mp4';
      final validFile = File(validPath);
      await validFile.writeAsBytes([1, 2, 3]);
      expect(await FileUtils.isFileReady(validFile), true);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}
