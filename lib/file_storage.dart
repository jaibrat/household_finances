// file_storage.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class FileStorage {
  /// Returns the external document directory (Downloads on Android)
  static Future<String> getExternalDocumentPath() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    Directory directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    print('Saved Path: ${directory.path}');
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
    print('File saved: ${file.path}');
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
        print('File does not exist: ${file.path}');
        return null;
      }
    } catch (e) {
      print('Error reading file: $e');
      return null;
    }
  }
}
