import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'ImportExportScreen.dart';
import 'camera_icon_plus_wdg.dart';
import 'camera_screen.dart';
import 'file_graph_screen.dart';
import 'filter.dart';
import 'flet.dart';
import 'pdf_parse_screen.dart';
import 'saldo_plot.dart';
import 'structured_list.dart';

void main() {
  runApp(MaterialApp(
    title: 'Finance Friend: collect receipts',
    theme: ThemeData(primarySwatch: Colors.green),
    home: MainScreen(),
  ));
}

// ---------------- MainScreen ----------------
class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  Directory? _cacheDir;

  String? _graphFileName;
  List<double> _graphValues = [];
  List<String> _graphFirstLines = [];
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    _initCacheDir();
  }

  Future<void> _initCacheDir() async {
    final dir = await getTemporaryDirectory();
    setState(() {
      _cacheDir = dir;
    });
    print("📂 Cache folder: ${dir.path}");
  }

  void _handleFileSelected(
      String fileName, List<double> values, List<String> firstLines) {
    setState(() {
      _graphFileName = fileName;
      _graphValues = values;
      _graphFirstLines = firstLines;
      _currentIndex = 4; // Graph index
    });
  }

  Future<bool> _onPop() async {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
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
      return true;
    }
  }

  List<Widget> get _screens {
    if (_cacheDir == null) {
      return [const Scaffold(body: Center(child: CircularProgressIndicator()))];
    }

    return [
      ManualEntryScreen(),
      CameraScreen(),
      ImportExportScreen(),
      SaldoPlotScreen(),
      GraphScreen(
        title: _graphFileName ?? "No file selected",
        data: _graphValues,
        firstLines: _graphFirstLines,
      ),
      FileExplorerScreen(onFileSelected: _handleFileSelected),
      const Center(
          child: Text(
              "© 2025 by jaibrat@gmail.com\nVersion 0.2.2-alpha\n⚖️ MIT License\nSoftware is as is, use at your own risk.")),
      FletScreen(),
      StructuredListScreen(folderPath: _cacheDir!.path),
      FilterScreen(
        rootDir: _cacheDir!,
        onFilterApplied: (parsedRows) {
          print("✅ Filter returned ${parsedRows.length} rows");
        },
      ),
      CombinedScreen(),
    ];
  }

  // Set this to false to hide debug-only items, even in debug builds
  final bool showDebugMenus = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onPop,
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex > 3 ? 3 : _currentIndex,
          type: BottomNavigationBarType.fixed,
          onTap: (index) {
            if (index == 4) {
              showMenu(
                context: context,
                position: const RelativeRect.fromLTRB(1000, 700, 10, 100),
                items: [
                  if (showDebugMenus)
                    PopupMenuItem(
                      value: 5,
                      child: Row(
                        children: const [
                          Icon(Icons.widgets, color: Colors.green),
                          SizedBox(width: 8),
                          Text("Explorer🧪for_debug")
                        ],
                      ),
                    ),
                  if (showDebugMenus)
                    PopupMenuItem(
                      value: 4,
                      child: Row(
                        children: const [
                          Icon(Icons.bar_chart, color: Colors.purple),
                          SizedBox(width: 8),
                          Text("Graph🧪for_debug")
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 6,
                    child: Row(
                      children: const [
                        Icon(Icons.widgets, color: Colors.green),
                        SizedBox(width: 8),
                        Text("Else: About & infoℹ️")
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 7,
                    child: Row(
                      children: const [
                        Icon(Icons.more_horiz, color: Colors.orange),
                        SizedBox(width: 8),
                        Text("Flet: future development")
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 10,
                    child: Row(
                      children: const [
                        Icon(Icons.picture_as_pdf, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Text("PDF-->Image✅")
                      ],
                    ),
                  ),
                ],
              ).then((value) {
                if (value != null) setState(() => _currentIndex = value);
              });
            } else {
              setState(() => _currentIndex = index);
            }
          },
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.note_add), label: "Home Enter"),
            BottomNavigationBarItem(
                icon: CameraPlusIcon(
                    size: 24, color: Color.fromARGB(255, 54, 54, 54)),
                label: "Camera"),
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

// ---------------- ManualEntryScreen ----------------
class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});
  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class Entry {
  String text;
  String number;
  String date;

  Entry({required this.text, required this.number, required this.date});

  Map<String, dynamic> toJson() => {
        'text': text,
        'tip': number, // "Number"
        'date': date,
      };
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _numController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
      text: DateFormat("yyyy-MM-dd").format(DateTime.now()));

  Future<String> _getFolderPath() async {
    final dir = await getApplicationDocumentsDirectory();
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<void> _saveEntry() async {
    final folder = Directory(await _getFolderPath());
    final counterFile = File('${folder.path}/counter.txt');
    int nextNumber = 1;

    if (counterFile.existsSync()) {
      try {
        nextNumber = int.tryParse(counterFile.readAsStringSync().trim()) ?? 1;
      } catch (_) {
        nextNumber = 1;
      }
    }

    final baseName = nextNumber.toString().padLeft(3, '0');

    // TXT file
    final txtFileName = 'entry$baseName.txt';
    final txtFile = File('${folder.path}/$txtFileName');
    final txtContent =
        "Text: ${_textController.text}\nNumber: ${_numController.text}\nDate: ${_dateController.text}";
    await txtFile.writeAsString(txtContent);

    // JSONTMP file using structured Entry class
    final entry = Entry(
      text: _textController.text,
      number: _numController.text,
      date: _dateController.text,
    );

    final jsonFileName = 'entry$baseName.jsonTMP';
    final jsonFile = File('${folder.path}/$jsonFileName');
    await jsonFile.writeAsString(jsonEncode(entry.toJson()));

    // Update counter
    await counterFile.writeAsString((nextNumber + 1).toString());

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Saved $txtFileName and $jsonFileName")));

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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 120,
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
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RichText(
                  textAlign: TextAlign.left, // <-- change from center to left
                  text: const TextSpan(
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                    children: [
                      TextSpan(
                        text: 'Welcome 👋 | Instructions for use\n\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            'Purpose: primarily for collecting receipts/bills\n',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'Home',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' --> Manually add an entry\n'),
                      TextSpan(
                        text: 'Camera',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                          text: ' --> Add an entry by camera or picture\n'),
                      TextSpan(
                        text: 'Import/Export',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' --> Get data In/Out of this App\n'),
                      TextSpan(
                        text: 'Saldo Plot',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                          text: ' --> Interactive plots of entered data\n'),
                      TextSpan(
                        text: 'More',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' --> Click & see for yourself\n'),
                      TextSpan(
                          text: '--> Ads are not present on alpha version\n'),
                      TextSpan(text: '--> More features to come!'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
