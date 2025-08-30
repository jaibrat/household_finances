import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'boxes.dart';

class ResultScreen extends StatefulWidget {
  final String result;
  final File imageFile; // 👈 add original image file

  const ResultScreen(this.result, this.imageFile, {super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String _status = "";

  Future<void> _saveToTxtFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath =
          '${dir.path}/result_${DateTime.now().millisecondsSinceEpoch}.txt';

      final file = File(filePath);
      await file.writeAsString(widget.result);

      setState(() {
        _status = "✅ Saved to: $filePath";
      });
    } catch (e) {
      setState(() {
        _status = "❌ Error saving file: $e";
      });
    }
  }

  Future<void> _showBoxes() async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(widget.imageFile);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final uiImage =
        await drawTextBoxesOnImage(widget.imageFile, recognizedText);
    final imageWidget = await imageFromUiImage(uiImage);

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Boxes_showB")),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(child: imageWidget),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // 👇 Your action here
                  DO_THIS();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "(usless) DO_THIS executed! (read/write *.jsonTMP)")),
                  );
                },
                child: const Text(
                    "(usless) Run DO_THIS -what boxes already saved-"),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.result,
                  showCursor: true,
                  cursorColor: Theme.of(context).colorScheme.secondary,
                  cursorWidth: 5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveToTxtFile,
              child: const Text("Save to TXT (usless)"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _showBoxes, // 👈 new button
              child: const Text("Analyse‼️ ('boxes')"),
            ),
            const SizedBox(height: 10),
            Text(_status,
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
