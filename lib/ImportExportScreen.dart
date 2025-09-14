import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'boxes.dart'; // where drawTextBoxesOnImage lives

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  _ImportExportScreenState createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> {
  String _status =
      "Export/Import via ZIP file & processing\n (This screen is scrollable.)";
  File? _lastExportedFile;
  Directory? _cacheDir;

  double _progress = 0.0;
  bool _isExporting = false;
  bool _isImporting = false;

  // OCR state
  bool _isOcrRunning = false;
  bool _cancelOcr = false;
  double _ocrProgress = 0.0;

  // delete filters
  bool _deleteJpg = false;
  bool _deleteJson = false;
  bool _deleteTxt = false;

  List<FileSystemEntity> _cacheFiles = [];

  @override
  void initState() {
    super.initState();
    _initDir();
  }

  Future<void> _initDir() async {
    final dir = await getTemporaryDirectory(); // ✅ cache folder
    print("📂 Cache folder path: ${dir.path}");
    setState(() => _cacheDir = dir);
  }

  Future<void> _refreshCacheFiles() async {
    if (_cacheDir == null) return;
    final files =
        _cacheDir!.listSync(recursive: false).where((f) => f is File).toList();

    print("🔎 Found ${files.length} cache files:");
    for (var f in files) {
      print("   - ${f.path}");
    }

    setState(() {
      _cacheFiles = files;
      _status = "Cache refreshed: ${files.length} files found.";
    });
  }

  // ------------------- OCR FUNCTIONS -------------------
  Future<void> _runOcrOnAll() async {
    if (_cacheFiles.isEmpty) {
      setState(() {
        _status = "No files in cache for OCR.";
      });
      return;
    }

    final imageFiles = _cacheFiles
        .where((f) =>
            f.path.toLowerCase().endsWith(".jpg") ||
            f.path.toLowerCase().endsWith(".png"))
        .toList();

    if (imageFiles.isEmpty) {
      setState(() {
        _status = "No images (.jpg/.png) found for OCR.";
      });
      return;
    }

    setState(() {
      _isOcrRunning = true;
      _cancelOcr = false;
      _ocrProgress = 0.0;
      _status = "Starting OCR on ${imageFiles.length} images...";
    });

    for (int i = 0; i < imageFiles.length; i++) {
      if (_cancelOcr) {
        setState(() {
          _status = "OCR cancelled at image ${i + 1}/${imageFiles.length}.";
          _isOcrRunning = false;
        });
        return;
      }

      final file = imageFiles[i] as File;
      print(file.path);

      try {
        await _processSingleImage(file);

        setState(() {
          _ocrProgress = (i + 1) / imageFiles.length;
          _status =
              "Processed ${i + 1}/${imageFiles.length}: ${p.basename(file.path)}";
        });
      } catch (e) {
        setState(() {
          _status = "Error on ${p.basename(file.path)}: $e";
        });
      }
    }

    setState(() {
      _isOcrRunning = false;
      _status = "OCR finished on ${imageFiles.length} images.";
    });
  }

  Future<void> _processSingleImage(File imageFile) async {
    print("📝 Performing OCR on: ${imageFile.path}");

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    debugPrint("Performing OCR on ${imageFile.path}");
    drawTextBoxesOnImage(imageFile, recognizedText); // placeholder
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // ------------------- DELETE FILES -------------------
  Future<void> _deleteSelectedFiles() async {
    try {
      final selectedExtensions = <String>[];
      if (_deleteJpg) selectedExtensions.add(".jpg");
      if (_deleteJson)
        selectedExtensions.add(".jsonTMP"); //žž uff, Lovro, mora biti riješeno
      if (_deleteTxt) selectedExtensions.add(".txt");

      if (selectedExtensions.isEmpty) {
        setState(() {
          _status = "No file types selected for deletion.";
        });
        return;
      }

      final cacheDir = await getTemporaryDirectory();
      final docsDir = await getApplicationDocumentsDirectory();
      print(docsDir);
      print(selectedExtensions);

      List<File> _filesInDir(Directory dir) {
        return dir.listSync(recursive: true).whereType<File>().where((f) {
          final path = f.path;
          final matchesExt =
              selectedExtensions.any((ext) => path.endsWith(ext));

          if (!matchesExt) return false;

          // Special rule: if .txt is selected, only delete entry*.txt, not counter*.txt
          if (path.endsWith(".txt")) {
            final name = f.uri.pathSegments.last.toLowerCase();
            if (name.startsWith("counter")) return false;
            if (name.startsWith("entry")) return true;
            return false;
          }

          return true;
        }).toList();
      }

      final filesToDelete = [
        ..._filesInDir(cacheDir),
        ..._filesInDir(docsDir),
      ];

      // Print which files survived filtering
      //for (final f in filesToDelete) {
      //  print("   ✅✅✅ Marked for delete: ${f.path}");
      //}

      if (filesToDelete.isEmpty) {
        setState(() {
          _status = "No matching files found to delete.";
        });
        return;
      }

      int deletedCount = 0;
      for (final file in filesToDelete) {
        try {
          await file.delete();
          print("🗑️ Deleted: ${file.path}");
          deletedCount++;
        } catch (e) {
          print("⚠️ Failed to delete ${file.path}: $e");
        }
      }

      await _refreshCacheFiles();

      setState(() {
        _status =
            "Deleted $deletedCount file(s): ${selectedExtensions.join(", ")}";
      });
    } catch (e) {
      setState(() {
        _status = "Error during delete: $e";
      });
    }
  }

  // ------------------- EXPORT -------------------
  Future<void> _shareExcelFiles() async {
    List<File> excelFiles = [];

    try {
      // 1️⃣ Look for .xlsx files in cache folder
      if (_cacheDir != null) {
        excelFiles = _cacheDir!
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith(".xlsx"))
            .toList();
      }

      // 2️⃣ If none found, check app documents directory
      if (excelFiles.isEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        excelFiles = appDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith(".xlsx"))
            .toList();
      }

      if (excelFiles.isEmpty) {
        setState(() => _status = "No .xlsx files found to share.");
        return;
      }

      // Convert to XFile for share_plus
      final xFiles = excelFiles.map((f) => XFile(f.path)).toList();

      await Share.shareXFiles(
        xFiles,
        subject: "Rapp Excel Export",
        text: "Here are the exported Excel files from Rapp.",
      );

      setState(() => _status = "Shared ${excelFiles.length} Excel file(s).");
    } catch (e) {
      setState(() => _status = "Failed to share Excel files: $e");
    }
  }

  Future<void> _exportZipFile() async {
    try {
      setState(() {
        _progress = 0.0;
        _isExporting = true;
        _status = "Starting export...";
      });

      final archive = Archive();
      final allowedExtensions = [
        ".txt",
        ".csv",
        ".xlsx",
        ".pdf",
        ".jpg",
        ".jsontmp"
      ];

      // 1️⃣ Get cache directory
      final cacheDir = await getTemporaryDirectory();
      final cacheFiles = cacheDir
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => allowedExtensions
              .any((ext) => f.path.toLowerCase().endsWith(ext)))
          .toList();

      // 2️⃣ Get app_flutter (documents) directory
      final docsDir = await getApplicationDocumentsDirectory();
      final docFiles = docsDir
          .listSync(recursive: false)
          .whereType<File>()
          .where((f) => allowedExtensions
              .any((ext) => f.path.toLowerCase().endsWith(ext)))
          .toList();

      // 3️⃣ Combine both sets
      final files = [...cacheFiles, ...docFiles];

      if (files.isEmpty) {
        setState(() {
          _status = "No matching files found in cache or app folder";
          _isExporting = false;
        });
        return;
      }

      // 4️⃣ Add files to archive
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        final data = await file.readAsBytes();
        final filename = p.basename(file.path);
        archive.addFile(ArchiveFile(filename, data.length, data));

        setState(() {
          _progress = (i + 1) / files.length;
          _status = "Adding $filename (${i + 1}/${files.length})";
        });
      }

      // 5️⃣ Save ZIP into cache
      final exportPath = p.join(cacheDir.path, "export_Rapp_cache.zip");
      final zipFile = File(exportPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(ZipEncoder().encode(archive)!);

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

  // ------------------- IMPORT -------------------
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

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    final busy = _isExporting || _isImporting;

    return Scaffold(
      appBar: AppBar(title: const Text("Import / Export")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  Text(_status),
                  const SizedBox(height: 20),

                  if (busy) ...[
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 20),
                  ],

                  ElevatedButton(
                    onPressed: _isExporting ? null : _exportZipFile,
                    child: const Text("Export Cache (*.*) → Rapp.ZIP"),
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
                    label: const Text(
                        "Share/Export all (*.*) via... (Email, etc.)"),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _shareExcelFiles,
                    icon: const Icon(Icons.file_present),
                    label: const Text("Share/Export All Excel Files"),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _refreshCacheFiles,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh"),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _isOcrRunning ? null : _runOcrOnAll,
                    icon: const Icon(Icons.precision_manufacturing),
                    label: const Text("Perform OCR on All"),
                  ),
                  const SizedBox(height: 20),

                  if (_isOcrRunning) ...[
                    LinearProgressIndicator(value: _ocrProgress),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _cancelOcr = true;
                        });
                      },
                      icon: const Icon(Icons.cancel),
                      label: const Text("Cancel OCR"),
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                    const SizedBox(height: 20),
                  ],

                  const Divider(),
                  const Text("Delete Files from Cache:",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  CheckboxListTile(
                    title: const Text("Delete .jpg"),
                    value: _deleteJpg,
                    onChanged: (val) =>
                        setState(() => _deleteJpg = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: const Text("Delete .json"),
                    value: _deleteJson,
                    onChanged: (val) =>
                        setState(() => _deleteJson = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    title: const Text("Delete .txt"),
                    value: _deleteTxt,
                    onChanged: (val) =>
                        setState(() => _deleteTxt = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  ElevatedButton.icon(
                    onPressed: _deleteSelectedFiles,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text("Delete Selected Files"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // finally your cache file list
                  ..._cacheFiles.map((f) => ListTile(
                        leading: const Icon(Icons.insert_drive_file),
                        title: Text(p.basename(f.path)),
                        subtitle: Text(f.path),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
