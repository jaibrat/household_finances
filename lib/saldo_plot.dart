// saldo_plot.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart' as ex;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SaldoPlotScreen extends StatefulWidget {
  const SaldoPlotScreen({super.key});

  @override
  State<SaldoPlotScreen> createState() => _SaldoPlotScreenState();
}

class _SaldoPlotScreenState extends State<SaldoPlotScreen> {
  List<Map<String, dynamic>> entries = [];
  int? touchedIndex;
  String selectedFileContent = "";
  bool showJsonTMP = true; // default on

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  double extractUkupnoValues(String text) {
    final regex = RegExp(r'\d{1,3},\d{2}');
    final matches = <double>[];

    final idx1 = text.toUpperCase().indexOf('UKUP');
    final idx2 = text.toUpperCase().indexOf('TOTAL');
    final idx3 = text.toUpperCase().indexOf('IZNO');

    if (idx1 == -1 && idx2 == -1 && idx3 == -1) return 0.0;

    final start = [idx1, idx2, idx3].where((i) => i != -1).reduce(max);
    final after = text.substring(start);

    for (final m in regex.allMatches(after)) {
      matches.add(double.parse(m.group(0)!.replaceAll(',', '.')));
    }

    if (matches.isEmpty) return 0.0;
    matches.sort((a, b) => b.compareTo(a));
    return matches.first;
  }

  Future<void> _loadFiles() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!dir.existsSync()) {
      setState(() => selectedFileContent = "Folder not found.");
      return;
    }

    // Only parse *.json files
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path
            .endsWith('.jsonTMP')) //žž Lovro ovo stvarno mora biti riješeno
        .toList();

    if (files.isEmpty) {
      setState(() => selectedFileContent = "No JSON files found.");
      return;
    }

    final tempEntries = <Map<String, dynamic>>[];
    final random = Random();
    final start = DateTime.now().subtract(const Duration(days: 365));
    final end = DateTime.now();

    DateTime randomDate() {
      final days = end.difference(start).inDays;
      return start.add(Duration(days: random.nextInt(days + 1)));
    }

    for (var file in files) {
      try {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);

        List<Map<String, dynamic>> items = [];
        if (decoded is List) {
          items = List<Map<String, dynamic>>.from(
              decoded.map((e) => Map<String, dynamic>.from(e)));
        } else if (decoded is Map) {
          items = [Map<String, dynamic>.from(decoded)];
        }

        for (var e in items) {
          double value = 0.0;
          try {
            final valStr = (e['tip'] ?? '0').toString().replaceAll(',', '.');
            value = double.parse(valStr);
          } catch (_) {}

          tempEntries.add({
            'file': file.path.split('/').last,
            'value': value,
            'date': DateTime.tryParse(e['datum'] ?? '') ?? randomDate(),
            'content': content,
            'file_image': e['file_image'] ?? '',
          });
        }
      } catch (e) {
        tempEntries.add({
          'file': file.path.split('/').last,
          'value': -10.0,
          'date': randomDate(),
          'content': 'Error parsing JSON: $e',
          'file_image': '',
        });
      }
    }

    tempEntries.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    setState(() {
      entries = tempEntries;
      selectedFileContent = entries.isNotEmpty ? entries[0]['content'] : "";
      touchedIndex = null;
    });
  }

  Future<void> _exportData(String format) async {
    if (entries.isEmpty) return;

    String output = "";
    if (format == "csv") {
      output = "Date,Value,File\n" +
          entries
              .map((e) =>
                  "${e['date'].toIso8601String()},${e['value']},${e['file']}")
              .join("\n");
    } else if (format == "txt") {
      output = entries
          .map((e) =>
              "${e['date'].toIso8601String()} | ${e['value']} | ${e['file']}")
          .join("\n");
    } else if (format == "json") {
      output = jsonEncode(entries
          .map((e) => {
                "date": e['date'].toIso8601String(),
                "value": e['value'],
                "file": e['file']
              })
          .toList());
    } else if (format == "xlsx") {
      final excel = ex.Excel.createExcel();
      final sheet = excel['Sheet1'];
      sheet.appendRow(['Date', 'Value', 'File']);
      for (var e in entries) {
        sheet.appendRow([e['date'].toIso8601String(), e['value'], e['file']]);
      }
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/saldo_plot_export.xlsx";
      final fileBytes = excel.encode();
      if (fileBytes != null) {
        await File(path).writeAsBytes(fileBytes);
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Data exported to $path")));
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/saldo_plot_export.$format";
    await File(path).writeAsString(output);

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("Data exported to $path")));
  }

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];

    if (showJsonTMP) {
      for (var i = 0; i < entries.length; i++) {
        final val = (entries[i]['value'] ?? 0).toDouble();
        spots.add(FlSpot(i.toDouble(), val));
      }
    } else {
      double total = 0.0;
      for (var i = 0; i < entries.length; i++) {
        // Ensure value is valid
        final val = entries[i]['value'] != null
            ? double.tryParse(entries[i]['value'].toString()) ?? 0
            : 0;
        total -= val;
        spots.add(FlSpot(i.toDouble(), total));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saldo Plot'),
        actions: [
          Row(
            children: [
              const Text("saldo <--> spline"), //JSONTMP
              Switch(
                value: showJsonTMP,
                onChanged: (val) {
                  setState(() => showJsonTMP = val);
                  _loadFiles();
                },
              ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: _exportData,
            itemBuilder: (context) => const [
              PopupMenuItem(value: "csv", child: Text("Export CSV")),
              PopupMenuItem(value: "txt", child: Text("Export TXT")),
              PopupMenuItem(value: "json", child: Text("Export JSON")),
              PopupMenuItem(value: "xlsx", child: Text("Export XLSX")),
            ],
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Chart
            Expanded(
              flex: 2,
              child: entries.isEmpty
                  ? const Center(child: Text("No data to plot"))
                  : LineChart(
                      LineChartData(
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < entries.length) {
                                  final date = entries[idx]['date'] as DateTime;
                                  return Transform.rotate(
                                    angle: -pi * 80 / 180,
                                    child: Text(
                                      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            isCurved: true,
                            spots: spots,
                            color: showJsonTMP ? Colors.blue : Colors.red,
                            barWidth: 3,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                if (index == touchedIndex) {
                                  return FlDotCirclePainter(
                                    radius: 6,
                                    color: Colors.red,
                                    strokeColor: Colors.black,
                                    strokeWidth: 1,
                                  );
                                }
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.blue,
                                  strokeColor: Colors.black,
                                  strokeWidth: 0.5,
                                );
                              },
                            ),
                          ),
                        ],
                        gridData: FlGridData(show: true),
                        borderData: FlBorderData(show: true),
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchCallback: (event, response) {
                            if (response != null &&
                                response.lineBarSpots != null &&
                                response.lineBarSpots!.isNotEmpty) {
                              setState(() {
                                touchedIndex =
                                    response.lineBarSpots!.first.x.toInt();
                                selectedFileContent =
                                    entries[touchedIndex!]['content'];
                              });
                            }
                          },
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) =>
                                Colors.black.withOpacity(0.7),
                            getTooltipItems: (spots) {
                              return spots.map((spot) {
                                final idx = spot.x.toInt();
                                final date = entries[idx]['date'] as DateTime;
                                return LineTooltipItem(
                                  '${entries[idx]['file']}\n${date.month}/${date.day}\nValue: ${entries[idx]['value']}',
                                  const TextStyle(color: Colors.white),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
            ),
            // Bottom panel
            Expanded(
              flex: 1,
              child: touchedIndex != null
                  ? Column(
                      children: [
                        // Image + info row
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.grey.shade100,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left info
                              Expanded(
                                flex: 2,
                                child: SingleChildScrollView(
                                  child: Text(
                                    "File: ${entries[touchedIndex!]['file']}\nValue: ${entries[touchedIndex!]['value']}\nDate: ${entries[touchedIndex!]['date']}\n\nClick & zoom the image  😉 ----->",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Right Hero image
                              Expanded(
                                flex: 1,
                                child: Builder(
                                  builder: (context) {
                                    final filePath = entries[touchedIndex!]
                                                ['file_image']
                                            ?.toString() ??
                                        '';
                                    if (filePath.isEmpty ||
                                        !File(filePath).existsSync()) {
                                      return const Icon(
                                          Icons.image_not_supported,
                                          size: 48,
                                          color: Colors.grey);
                                    }
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => Scaffold(
                                              backgroundColor: Colors.black,
                                              appBar: AppBar(
                                                backgroundColor: Colors.black,
                                                leading: IconButton(
                                                  icon: const Icon(
                                                      Icons.arrow_back,
                                                      color: Colors.white),
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                ),
                                              ),
                                              body: Center(
                                                child: Hero(
                                                  tag: 'image_$filePath',
                                                  child: InteractiveViewer(
                                                    panEnabled: true,
                                                    boundaryMargin:
                                                        const EdgeInsets.all(
                                                            20),
                                                    minScale: 0.5,
                                                    maxScale: 4,
                                                    child: Image.file(
                                                      File(filePath),
                                                      fit: BoxFit.contain,
                                                      errorBuilder: (context,
                                                              error,
                                                              stackTrace) =>
                                                          const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 48,
                                                              color:
                                                                  Colors.red),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      child: Hero(
                                        tag: 'image_$filePath',
                                        child: Image.file(
                                          File(filePath),
                                          fit: BoxFit.cover,
                                          height: 100,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const Icon(Icons.broken_image,
                                                      size: 48,
                                                      color: Colors.red),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Scrollable content
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade400),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                selectedFileContent,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: Text(
                          selectedFileContent,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
