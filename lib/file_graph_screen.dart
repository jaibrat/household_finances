import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for MethodChannel
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // for storage permissions

import 'utils.dart';

// ---------------- FileExplorerScreen ----------------
class FileExplorerScreen extends StatefulWidget {
  final Function(String, List<double>, List<String>) onFileSelected;
  FileExplorerScreen({required this.onFileSelected});
  @override
  _FileExplorerScreenState createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  Directory? currentDir;
  List<FileSystemEntity> entities = [];

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadFiles();
  }

  Future<void> _requestPermissionAndLoadFiles() async {
    await requestAllFilesAccess();
    if (await Permission.storage.isGranted ||
        await Permission.manageExternalStorage.isGranted) {
      final cacheDir = await getTemporaryDirectory(); // ✅ use cache
      setState(() => currentDir = cacheDir);
      _loadFiles();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Storage permission denied")),
        );
      }
    }
  }

  Future<void> _loadFiles() async {
    if (currentDir == null) return;
    try {
      setState(() {
        entities = currentDir!.listSync();
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error loading folder: $e")));
    }
  }

  void _goUpFolder() {
    if (currentDir == null) return;
    setState(() => currentDir = currentDir!.parent);
    _loadFiles();
  }

  Future<void> _openEntity(FileSystemEntity entity) async {
    if (entity is Directory) {
      setState(() => currentDir = entity);
      _loadFiles();
    } else if (entity is File) {
      try {
        final lines = await entity.readAsLines();
        final firstLines = lines.take(3).toList();
        final extracted = extractUkupnoValues(lines.join("\n"));
        final values = extracted
            .map((e) => double.tryParse(e.replaceAll(',', '.')) ?? 0)
            .toList();
        final name = entity.path.split('/').last;
        widget.onFileSelected(name, values, firstLines);
        DateTime lastModified = await entity.lastModified();
        String formattedDate = DateFormat("yyyy-MM-dd").format(lastModified);
        String displayText = "First 3 lines:\n${firstLines.join("\n")}";
        if (extracted.isNotEmpty)
          displayText += "\nExtracted ukupno values: ${extracted.join(", ")}";

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text("$name\nModified: $formattedDate\n\n$displayText"),
                duration: const Duration(seconds: 6)),
          );
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Error opening file: $e")));
      }
    }
  }

  Future<void> requestAllFilesAccess() async {
    if (Platform.isAndroid && await Permission.manageExternalStorage.isDenied) {
      bool granted = await Permission.manageExternalStorage.request().isGranted;
      if (!granted) openAppSettings();
    }
  }

  Future<void> refreshMediaStore(String folderPath) async {
    try {
      const platform = MethodChannel('media_scanner');
      await platform.invokeMethod('scanFolder', {'path': folderPath});
    } catch (e) {
      print("Media scan failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPath = currentDir?.path ?? "";
    return Scaffold(
      appBar: AppBar(
        title: const Text("Explorer"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Media Store",
            onPressed: () async {
              if (currentDir != null) {
                await refreshMediaStore(currentDir!.path);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Media Store refreshed")),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: _goUpFolder,
            tooltip: "Go Up",
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            width: double.infinity,
            child: Text("Path: $currentPath",
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: entities.isEmpty
                ? const Center(child: Text("No files in this folder"))
                : ListView.builder(
                    itemCount: entities.length,
                    itemBuilder: (context, index) {
                      final entity = entities[index];
                      final name = entity.path.split('/').last;
                      return ListTile(
                        leading: Icon(
                            entity is Directory
                                ? Icons.folder
                                : Icons.insert_drive_file,
                            color: entity is Directory
                                ? Colors.amber
                                : Colors.blueGrey),
                        title: Text(name),
                        onTap: () => _openEntity(entity),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------- GraphScreen ----------------
class GraphScreen extends StatelessWidget {
  final String title;
  final List<double> data;
  final List<String> firstLines;
  const GraphScreen(
      {Key? key,
      required this.title,
      required this.data,
      required this.firstLines})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasData = data.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (firstLines.isNotEmpty)
              Container(
                alignment: Alignment.centerLeft,
                margin: const EdgeInsets.only(bottom: 16),
                child: Text(firstLines.join("\n"),
                    style: const TextStyle(
                        fontSize: 16, fontStyle: FontStyle.italic)),
              ),
            Expanded(
              child: hasData
                  ? BarChart(
                      BarChartData(
                        barGroups: data.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                  toY: entry.value, color: Colors.blue)
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) =>
                                  Text("${value.toInt()}"),
                            ),
                          ),
                        ),
                      ),
                    )
                  : const Center(child: Text("No data")),
            ),
          ],
        ),
      ),
    );
  }
}
