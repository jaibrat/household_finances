import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  _ImportExportScreenState createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  String _status =
      "Export/Import via ZIP file. Delete is done by uninstalling app./clenar cache.";
  File? _lastExportedFile;
  Directory? _cacheDir;

  double _progress = 0.0;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _initDir();
  }

  // Add this inside _ImportExportScreenState:

  List<FileSystemEntity> _cacheFiles = [];

  Future<void> _refreshCacheFiles() async {
    if (_cacheDir == null) return;
    final files =
        _cacheDir!.listSync(recursive: false).where((f) => f is File).toList();

    setState(() {
      _cacheFiles = files;
      _status = "Cache refreshed: ${files.length} files found.";
    });
  }

  Future<void> _initDir() async {
    final dir = await getTemporaryDirectory(); // ✅ cache folder
    setState(() => _cacheDir = dir);
  }

  Future<void> _exportZipFile() async {
    if (_cacheDir == null) return;

    try {
      setState(() {
        _progress = 0.0;
        _isExporting = true;
        _status = "Starting export...";
      });

      final allowedExtensions = [".txt", ".csv", ".jpg", ".jsonTMP"];

      final files = _cacheDir!
          .listSync(recursive: false)
          .where((f) =>
              f is File &&
              allowedExtensions
                  .any((ext) => f.path.toLowerCase().endsWith(ext)))
          .cast<File>()
          .toList();

      if (files.isEmpty) {
        setState(() {
          _status = "No matching files found in cache folder";
          _isExporting = false;
        });
        return;
      }

      final archive = Archive();

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final data = await file.readAsBytes();
        final filename = p.basename(file.path);
        archive.addFile(ArchiveFile(filename, data.length, data));

        setState(() {
          _progress = (i + 1) / files.length;
          _status = "Adding $filename (${i + 1}/${files.length})";
        });

        await Future.delayed(const Duration(milliseconds: 200));
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        setState(() {
          _status = "Failed to encode ZIP";
          _isExporting = false;
        });
        return;
      }

      final exportPath = p.join(_cacheDir!.path, "export_rapp_cache.zip");
      final zipFile = File(exportPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(zipData);

      setState(() {
        _status = "Exported ZIP: $exportPath";
        _lastExportedFile = zipFile;
        _isExporting = false;
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _status = "Error: $e";
        _isExporting = false;
      });
    }
  }

  Future<void> _importZipFile() async {
    try {
      setState(() {
        _isImporting = true;
        _status = "Picking a ZIP file...";
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _status = "No ZIP file selected";
          _isImporting = false;
        });
        return;
      }

      final pickedFile = File(result.files.single.path!);
      final bytes = await pickedFile.readAsBytes();

      setState(() {
        _status = "Extracting ${p.basename(pickedFile.path)}...";
        _progress = 0.0;
      });

      final archive = ZipDecoder().decodeBytes(bytes);
      final totalFiles = archive.length;

      for (int i = 0; i < totalFiles; i++) {
        final file = archive[i];
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File(p.join(_cacheDir!.path, file.name));
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);
        }

        setState(() {
          _progress = (i + 1) / totalFiles;
          _status = "Extracting ${file.name} (${i + 1}/$totalFiles)";
        });

        await Future.delayed(const Duration(milliseconds: 150));
      }

      setState(() {
        _status = "Import completed. ${archive.length} files extracted.";
        _isImporting = false;
        _progress = 1.0;
      });
    } catch (e) {
      setState(() {
        _status = "Import failed: $e";
        _isImporting = false;
      });
    }
  }

  Future<void> _shareExportedFile() async {
    if (_lastExportedFile == null || !await _lastExportedFile!.exists()) {
      setState(() => _status = "No exported ZIP to share yet");
      return;
    }

    try {
      await Share.shareXFiles(
        [XFile(_lastExportedFile!.path)],
        subject: "Rapp Exported Cache Data",
        text: "Here’s the exported ZIP file containing cached Rapp files.",
      );
    } catch (e) {
      setState(() => _status = "Share failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isExporting || _isImporting;

    return Scaffold(
      appBar: AppBar(title: const Text("Import / Export")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(_status),
            const SizedBox(height: 20),

            if (busy) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 20),
            ],

            ElevatedButton(
              onPressed: _isExporting ? null : _exportZipFile,
              child: const Text("Export Cache → ZIP"),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isImporting ? null : _importZipFile,
              child: const Text("Import ZIP → Cache"),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _shareExportedFile,
              icon: const Icon(Icons.email),
              label: const Text("Share via Email"),
            ),
            const SizedBox(height: 20),

            // 🔄 New Refresh button
            ElevatedButton.icon(
              onPressed: _refreshCacheFiles,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh"),
            ),
            const SizedBox(height: 20),

            // Show files in cache
            Expanded(
              child: ListView.builder(
                itemCount: _cacheFiles.length,
                itemBuilder: (context, index) {
                  final f = _cacheFiles[index];
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(p.basename(f.path)),
                    subtitle: Text(f.path),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
