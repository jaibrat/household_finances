// image_with_text_box.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // ✅ ByteData
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'boxes.dart'; // import Box2

class ImageWithTextBox extends StatefulWidget {
  final ui.Image uiImage;
  final Box2 box; // Box2 object from boxes.dart
  final String datum; // Date string to save

  const ImageWithTextBox({
    super.key,
    required this.uiImage,
    required this.box,
    required this.datum,
  });

  @override
  State<ImageWithTextBox> createState() => _ImageWithTextBoxState();
}

class _ImageWithTextBoxState extends State<ImageWithTextBox> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _saveAsJson() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/data_${DateTime.now().millisecondsSinceEpoch}.json');

      final data = {
        "datum": widget.datum,
        "Match_naziv": widget.box.txt,
        "Match_iznos": widget.box.tip,
      };

      await file.writeAsString(jsonEncode(data), flush: true);

      print("✅ Saved JSON to: ${file.path}");
      print('datum: ${widget.datum}');
      print('Match_naziv: ${widget.box.txt}');
      print('Match_iznos: ${widget.box.tip}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved JSON to ${file.path}')),
        );
      }
    } catch (e) {
      print("❌ Error saving JSON: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Image + Notes")),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<ByteData?>(
              future: widget.uiImage.toByteData(format: ui.ImageByteFormat.png),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Image.memory(snapshot.data!.buffer.asUint8List());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Enter text here",
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _saveAsJson,
                  icon: const Icon(Icons.save),
                  label: const Text("Save as JSON"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
