import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ImportExportScreen.dart'; // <-- new import/export screen
import 'camera_screen.dart';
import 'filter.dart';
import 'flet.dart';
import 'pdf_parse_screen.dart';
import 'saldo_plot.dart';
import 'structured_list.dart';

void main() {
  runApp(MaterialApp(
    title: 'File Explorer2',
    theme: ThemeData(primarySwatch: Colors.green),
    home: MainScreen(),
  ));
}

/// ---- Shared extractor so both Explorer & Search can use it ----
List<String> extractUkupnoValues(String text) {
  final regex = RegExp(r'\d{1,3},\d{2}');
  final matches = <double>[];

  final idx1 = text.toUpperCase().indexOf('UKUP');
  final idx2 = text.toUpperCase().indexOf('TOTAL');
  final idx3 = text.toUpperCase().indexOf('IZNO');

  if (idx1 == -1 && idx2 == -1 && idx3 == -1) return [];

  final start = [idx1, idx2, idx3].reduce((a, b) => a > b ? a : b);
  final after = text.substring(start);

  for (final m in regex.allMatches(after)) {
    matches.add(double.parse(m.group(0)!.replaceAll(',', '.')));
    if (matches.length == 5) break;
  }

  matches.sort((a, b) => b.compareTo(a));
  if (matches == []) return ["0"]; //Lovro dodao
  return matches.map((e) => e.toStringAsFixed(2).replaceAll('.', ',')).toList();
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // default Manual Entry
  Directory rootDir = Directory("/storage/emulated/0/Download/Rapp");

  String? _graphFileName;
  List<double> _graphValues = [];
  List<String> _graphFirstLines = [];

  DateTime? _lastBackPress;
  List<Map<String, dynamic>> _structuredRows = []; // ✅ holds parsed rows

  void _handleFileSelected(
      String fileName, List<double> values, List<String> firstLines) {
    setState(() {
      _graphFileName = fileName;
      _graphValues = values;
      _graphFirstLines = firstLines;
      _currentIndex = 4; // when Graph is opened from More
    });
  }

  Future<bool> _onPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0); // go to Manual Entry first
      return false;
    } else {
      final now = DateTime.now();
      if (_lastBackPress == null ||
          now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
        _lastBackPress = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Press back again to exit"),
            duration: Duration(seconds: 2),
          ),
        );
        return false;
      }
      return true; // exit app
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      ManualEntryScreen(), // index 0
      CameraScreen(), // index 1
      ImportExportScreen(), //          rootDir: rootDir), // index 2 (NEW screen instead of Graph)
      SaldoPlotScreen(),
      GraphScreen(
        // index 4, only via More
        title: _graphFileName ?? "No file selected",
        data: _graphValues,
        firstLines: _graphFirstLines,
      ),
      FileExplorerScreen(onFileSelected: _handleFileSelected), // index 5
      Center(child: Text("Flet Screen")), // index 6 (placeholder)
      FletScreen(), // index 7 (placeholder)
      StructuredListScreen(
        folderPath: "/storage/emulated/0/Download/Rapp",
      ), // index 8 // 8 👈 NEW
      FilterScreen(
        rootDir: rootDir,
        onFilterApplied: (parsedRows) {
          print("✅ Filter returned ${parsedRows.length} rows");
          for (var row in parsedRows) {
            print(row);
          }

          // You can pass parsedRows to GraphScreen here
          //dummy.dart2
        },
      ), // index 3 (NEW screen instead of Search), //Center(child: Text("Flet mjenja salda")),//SaldoPlotScreen(),            // 9 👈 NEW screen
      CombinedScreen(), // 👈 index 10
    ];

    return WillPopScope(
      onWillPop: _onPop,
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex > 3 ? 3 : _currentIndex, // clamp for nav
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            if (index == 4) {
              // "More" tapped
              showMenu(
                context: context,
                position: const RelativeRect.fromLTRB(1000, 700, 10, 100),
                items: [
                  PopupMenuItem(
                    value: 4,
                    child: Row(
                      children: const [
                        Icon(Icons.bar_chart, color: Colors.purple),
                        SizedBox(width: 8),
                        Text("Graph🧪"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 5,
                    child: Row(
                      children: const [
                        Icon(Icons.folder, color: Colors.blue),
                        SizedBox(width: 8),
                        Text("Explorer🧪❌"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 6,
                    child: Row(
                      children: const [
                        Icon(Icons.widgets, color: Colors.green),
                        SizedBox(width: 8),
                        Text("Flet✅"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 7,
                    child: Row(
                      children: const [
                        Icon(Icons.more_horiz, color: Colors.orange),
                        SizedBox(width: 8),
                        Text("Else✅"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 8,
                    child: Row(
                      children: const [
                        Icon(Icons.list, color: Colors.teal),
                        SizedBox(width: 8),
                        Text("Structured List🧪❌"),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 9,
                    child: Row(
                      children: const [
                        Icon(Icons.search, color: Colors.pink),
                        SizedBox(width: 8),
                        Text("Filter-Search🧪❌"), //‼️‼️
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 10, // 👈 make sure it's unique
                    child: Row(
                      children: const [
                        Icon(Icons.picture_as_pdf, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Text("PDF-->Image✅"),
                      ],
                    ),
                  ),
                ],
              ).then((value) {
                if (value != null) {
                  setState(() => _currentIndex = value);
                }
              });
            } else {
              setState(() => _currentIndex = index);
            }
          },
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.note_add), label: "Manual Entry"),
            BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt), label: "Camera"),
            BottomNavigationBarItem(
                icon: Icon(Icons.import_export), label: "Import/Export"),
            BottomNavigationBarItem(
                icon: Icon(Icons.show_chart), label: "Saldo Plot"),
            BottomNavigationBarItem(
                icon: Icon(Icons.more_horiz), label: "More"),
          ],
        ),
      ),
    );
  }
}

/// ---------------- HomePage, MyHomePage, SearchScreen, GraphScreen ----------------
/// (unchanged, same as your big code above)

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _numController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
      text: DateFormat("yyyy-MM-dd").format(DateTime.now()));

  Future<String> _getFolderPath() async {
    //final dir = Directory.systemTemp; // Replace with your desired folder
    final dir =
        await getApplicationDocumentsDirectory(); // Flutter's documents folder
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir.path;
  }

  Future<void> _saveEntry() async {
    final folderPath = await _getFolderPath();
    final folder = Directory(folderPath);

    // Counter file
    final counterFile = File('${folder.path}/counter.txt');
    int nextNumber = 1;

    // Read counter if exists
    if (counterFile.existsSync()) {
      try {
        final text = counterFile.readAsStringSync().trim();
        nextNumber = int.tryParse(text) ?? 1;
      } catch (_) {
        nextNumber = 1;
      }
    }

    // Build file name using padded number
    final fileName = 'entry${nextNumber.toString().padLeft(3, '0')}.txt';
    final file = File('${folder.path}/$fileName');
    print("Saving to (manual-entry-screen) ${file.path}");

    // Write content
    final content =
        "Text: ${_textController.text}\nNumber: ${_numController.text}\nDate: ${_dateController.text}";
    await file.writeAsString(content);

    // Update counter for next time
    await counterFile.writeAsString((nextNumber + 1).toString());

    // Notify user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved $fileName")),
    );

    // Clear inputs (optional: reset date to today)
    _textController.clear();
    _numController.clear();
    _dateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Entry')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Text box (4x bigger)
            SizedBox(
              height: 200,
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  labelText: "Enter text",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Number box (2x smaller)
            SizedBox(
              height: 40,
              child: TextField(
                controller: _numController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Number",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Date box (new 3rd box)
            SizedBox(
              height: 40,
              child: TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: "Date (yyyy-MM-dd)",
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveEntry,
              child: const Text('Save Entry'),
            ),
          ],
        ),
      ),
    );
  }
}

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
    // Request MANAGE_EXTERNAL_STORAGE first
    await requestAllFilesAccess();

    // Then check storage permission
    if (await Permission.storage.isGranted ||
        await Permission.manageExternalStorage.isGranted) {
      setState(() {
        currentDir = Directory("/storage/emulated/0/Download/Rapp");
      });
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading folder: $e")),
        );
      }
    }
  }

  void _goUpFolder() {
    if (currentDir == null) return;
    final parent = currentDir!.parent;
    setState(() {
      currentDir = parent;
    });
    _loadFiles();
  }

  Future<void> _openEntity(FileSystemEntity entity) async {
    if (entity is Directory) {
      setState(() {
        currentDir = entity;
      });
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

        // Push to graph via callback
        widget.onFileSelected(name, values, firstLines);

        // Snack summary
        DateTime lastModified = await entity.lastModified();
        String formattedDate = DateFormat("yyyy-MM-dd").format(lastModified);
        String displayText = "First 3 lines:\n${firstLines.join("\n")}";
        if (extracted.isNotEmpty) {
          displayText += "\nExtracted ukupno values: ${extracted.join(", ")}";
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "$name\nModified: $formattedDate\n\n$displayText",
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error opening file: $e")),
          );
        }
      }
    }
  }

  Future<void> requestAllFilesAccess() async {
    if (Platform.isAndroid && await Permission.manageExternalStorage.isDenied) {
      bool granted = await Permission.manageExternalStorage.request().isGranted;

      if (!granted) {
        // Open app settings for user to enable it manually
        openAppSettings();
      }
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
            child: Text(
              "Path: $currentPath",
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
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
                              : Colors.blueGrey,
                        ),
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

class GraphScreen extends StatelessWidget {
  final String title;
  final List<double> data;
  final List<String> firstLines;

  const GraphScreen({
    Key? key,
    required this.title,
    required this.data,
    required this.firstLines,
  }) : super(key: key);

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
                child: Text(
                  firstLines.join("\n"),
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
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
                                  toY: entry.value, color: Colors.blue),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true),
                          ),
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
