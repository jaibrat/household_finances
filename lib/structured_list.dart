import 'dart:io';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:charset_converter/charset_converter.dart'; // <-- add in pubspec.yaml

class StructuredListScreen extends StatefulWidget {
  final String folderPath;

  const StructuredListScreen({Key? key, required this.folderPath})
      : super(key: key);

  @override
  State<StructuredListScreen> createState() => _StructuredListScreenState();
}

class _StructuredListScreenState extends State<StructuredListScreen> {
  List<FileSystemEntity> files = [];
  String? selectedContent;
  List<List<dynamic>>? csvRows;
  bool showTxt = true; // true -> show .txt, false -> show .csv

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  void _loadFiles() {
    final dir = Directory(widget.folderPath);
    if (!dir.existsSync()) return;

    setState(() {
      files = dir
          .listSync()
          .whereType<File>()
          .where((file) => showTxt
              ? file.path.endsWith('.txt')
              : file.path.endsWith('.csv'))
          .toList();
      selectedContent = null;
      csvRows = null;
    });
  }

  Future<void> _loadFileContent(File file) async {
    try {
      // Detect encoding automatically and convert to UTF-8
      final bytes = await file.readAsBytes();
      String content;
      try {
        content = await CharsetConverter.decode("utf-8", bytes);
      } catch (_) {
        // fallback to Latin1
        content = await CharsetConverter.decode("latin1", bytes);
      }

      if (file.path.endsWith('.csv')) {
        // parse CSV
        final rows = const CsvToListConverter().convert(content);
        setState(() {
          csvRows = rows;
          selectedContent = null; // hide plain text
        });
      } else {
        setState(() {
          selectedContent = content;
          csvRows = null;
        });
      }
    } catch (e) {
      setState(() {
        selectedContent = "Error reading file: $e";
        csvRows = null;
      });
    }
  }

  void _toggleFileType(bool value) {
    setState(() {
      showTxt = value;
      _loadFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Files Viewer (${showTxt ? "*.txt" : "*.csv"})"),
        actions: [
          Row(
            children: [
              const Text("TXT"),
              Switch(
                value: !showTxt,
                onChanged: (val) => _toggleFileType(!val),
                activeColor: Colors.white,
                inactiveThumbColor: Colors.white,
              ),
              const Text("CSV"),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: File list
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index] as File;
                final fileName = file.path.split('/').last;
                return Card(
                  margin: const EdgeInsets.all(4),
                  child: ListTile(
                    title: Text(fileName),
                    onTap: () => _loadFileContent(file),
                  ),
                );
              },
            ),
          ),

          // Right: File content
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey.shade100,
              child: csvRows != null
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: List.generate(
                          csvRows![0].length,
                          (index) => DataColumn(
                            label: Text(csvRows![0][index].toString(),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        rows: List.generate(
                          csvRows!.length - 1,
                          (rowIndex) => DataRow(
                            cells: List.generate(
                              csvRows![rowIndex + 1].length,
                              (colIndex) => DataCell(
                                Text(csvRows![rowIndex + 1][colIndex].toString(),
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Text(
                        selectedContent ?? "Select a file to view its content",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
