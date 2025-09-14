// file_storage.dart
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FileStorage {
  /// Returns the external document directory (platform safe)
  static Future<String> getExternalDocumentPath() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    Directory directory;

    if (Platform.isAndroid) {
      // ✅ Use system-managed external storage (e.g., Android/data/<app>/files)
      directory = (await getExternalStorageDirectory())!;
    } else {
      // iOS / Desktop fallback
      directory = await getApplicationDocumentsDirectory();
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    print('📂 Storage Path: ${directory.path}');
    return directory.path;
  }

  /// Returns the local path for saving files
  static Future<String> get _localPath async {
    final path = await getExternalDocumentPath();
    return path;
  }

  /// Writes [content] to a file named [filename] in the external directory
  static Future<File> writeCounter(String content, String filename) async {
    final path = await _localPath;
    final file = File('$path/$filename');

    await file.writeAsString(content, mode: FileMode.write);
    print('✅ File saved: ${file.path}');
    return file;
  }

  /// Reads content from a file named [filename]
  static Future<String?> readCounter(String filename) async {
    try {
      final path = await _localPath;
      final file = File('$path/$filename');
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        print('⚠️ File does not exist: ${file.path}');
        return null;
      }
    } catch (e) {
      print('❌ Error reading file: $e');
      return null;
    }
  }

  /// Lists all files in the storage/cache directory
  static Future<List<FileSystemEntity>> listFiles() async {
    final path = await _localPath;
    final directory = Directory(path);

    if (!await directory.exists()) {
      print('⚠️ Directory does not exist: $path');
      return [];
    }

    final files = directory.listSync(recursive: false, followLinks: false);
    print('📂 Found ${files.length} file(s) in $path');
    for (var f in files) {
      print('   - ${f.path}');
    }

    return files;
  }
}
