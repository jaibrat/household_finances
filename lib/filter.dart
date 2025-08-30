import 'dart:io';
import 'dart:convert'; // ✅ for utf8 & latin1
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';


class FilterScreen extends StatefulWidget {
  final Directory rootDir;
  final Function(List<Map<String, dynamic>> parsedRows) onFilterApplied;

  const FilterScreen({
    Key? key,
    required this.rootDir,
    required this.onFilterApplied,
  }) : super(key: key);

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

/// Simple Windows-1250 decoder (fallback)
class Windows1250Decoder extends Converter<List<int>, String> {
  const Windows1250Decoder();

  @override
  String convert(List<int> input) {
    return input.map((b) => String.fromCharCode(b)).join();
  }
}

class _FilterScreenState extends State<FilterScreen> {
  final TextEditingController _textController = TextEditingController();
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _lastFiltered = []; // store last filtered rows

  /// Reads CSV safely with fallback encodings
  Future<List<String>> readCsvFile(File file) async {
    try {
      return await file.readAsLines(encoding: utf8);
    } catch (_) {
      try {
        return await file.readAsLines(encoding: latin1);
      } catch (_) {
        final bytes = await file.readAsBytes();
        return const Windows1250Decoder().convert(bytes).split("\n");
      }
    }
  }

  /// 🔍 Finds and parses CSV files into structured rows
Future<List<Map<String, dynamic>>> focus1() async {
  List<Map<String, dynamic>> allRows = [];

  final csvFiles = widget.rootDir
      .listSync()
      .where((f) => f is File && f.path.toLowerCase().endsWith(".csv"))
      .map((f) => f as File);

  for (var file in csvFiles) {
    final lines = await readCsvFile(file);
    if (lines.isEmpty) continue;

    // Join all lines into a single string
    final content = lines.join("\n");

    // Automatically detect delimiter: comma or semicolon
    final delimiter = content.contains(";") ? ";" : ",";

    // Parse CSV using CsvToListConverter, handle quoted fields
    final converter = CsvToListConverter(
      eol: '\n',
      fieldDelimiter: delimiter,
      shouldParseNumbers: false, // we'll parse manually
    );

    final rows = converter.convert(content);

    if (rows.isEmpty) continue;

    // first row = headers
    final headers = rows.first.map((h) => h.toString().trim()).toList();

    // process remaining rows
    for (var i = 1; i < rows.length; i++) {
      final rowList = rows[i];
      if (rowList.every((v) => v.toString().trim().isEmpty)) continue;

      final row = <String, dynamic>{};
      for (var j = 0; j < headers.length; j++) {
        final value = j < rowList.length ? rowList[j].toString().trim() : "";

        if (headers[j].toLowerCase().contains("number")) {
          row[headers[j]] = int.tryParse(value) ?? 0;
        } else if (headers[j].toLowerCase().contains("date")) {
          // parse dd.MM.yyyy format
          try {
            final parts = value.split('.');
            if (parts.length == 3) {
              row[headers[j]] = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            } else {
              row[headers[j]] = DateTime.tryParse(value) ?? DateTime(1970);
            }
          } catch (_) {
            row[headers[j]] = DateTime(1970);
          }
        } else if (headers[j].toLowerCase().contains("num") ||
            headers[j].toLowerCase().contains("iznos")) {
          row[headers[j]] =
              double.tryParse(value.replaceAll(',', '.').replaceAll(' HRK', '')) ?? 0.0;
        } else {
          row[headers[j]] = value;
        }
      }
      allRows.add(row);
    }
  }

  return allRows;
}

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
    );

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  /// Apply filter and notify parent
  void _applyFilter() async {
    final keyword = _textController.text.trim();
    final rows = await focus1();

    final filtered = rows.where((row) {
      final matchesKeyword = keyword.isEmpty ||
          row.values.any((v) =>
              v.toString().toLowerCase().contains(keyword.toLowerCase()));

      final matchesDate = _selectedDateRange == null ||
          row.values.every((v) =>
              v is! DateTime ||
              (!v.isBefore(_selectedDateRange!.start) &&
                  !v.isAfter(_selectedDateRange!.end)));

      return matchesKeyword && matchesDate;
    }).toList();

    _lastFiltered = filtered;

    widget.onFilterApplied(filtered);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Filter applied! Found ${filtered.length} rows.")),
    );
  }

  /// Print all rows parsed
  void _printFiltered() {
  if (_lastFiltered.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No filtered rows to print.")),
    );
    return;
  }
  List<String> _consoleOutput = [];

  _consoleOutput.clear(); // clear previous

  for (var i = 0; i < _lastFiltered.length && i < 10; i++) {
    final row = _lastFiltered[i];
    final rowText = row.entries.map((e) => "${e.key}: ${e.value}").join(", ");
    _consoleOutput.add(rowText);
    debugPrint(rowText);
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Printed first 10 filtered rows to console.")),
  );

  // Navigate to preview screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ConsoleOutputScreen(output: _consoleOutput),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final dateLabel = _selectedDateRange == null
        ? "No range selected"
        : "${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} → ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}";

    return Scaffold(
      appBar: AppBar(title: const Text("Filter Data")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: "Enter keyword",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text("Date range: $dateLabel")),
                ElevatedButton(
                  onPressed: _pickDateRange,
                  child: const Text("Pick Range"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _applyFilter,
              icon: const Icon(Icons.search),
              label: const Text("Apply Filter"),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _printFiltered,
              icon: const Icon(Icons.print),
              label: const Text("Print Parsed Rows"),
            ),
          ],
        ),
      ),
    );
  }
}


// ConsoleOutputScreen to show printed rows on phone
class ConsoleOutputScreen extends StatelessWidget {
  final List<String> output;

  const ConsoleOutputScreen({Key? key, required this.output}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Console Output")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: output.length,
          itemBuilder: (context, index) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(output[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}