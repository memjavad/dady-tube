import 'dart:io';

class FileUtils {
  /// Checks if a file exists and has content (length > 0).
  static Future<bool> isFileReady(File file) async {
    return await file.exists() && (await file.length()) > 0;
  }
}
