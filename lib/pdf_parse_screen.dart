import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import 'ml.dart'; // make sure this imports MLHelper

class CombinedScreen extends StatefulWidget {
  const CombinedScreen({super.key});

  @override
  State<CombinedScreen> createState() => _CombinedScreenState();
}

class _CombinedScreenState extends State<CombinedScreen> {
  String message = "";
  String mlResult = "1. Save Image <-- PDF\n2. Run ML to check result";

  Uint8List? lastImageBytes;

  Future<void> saveImage(Uint8List imageBytes) async {
    final externalDir = await getExternalStorageDirectory();
    final now = DateTime.now();
    final formatter = DateFormat('yyyyMMdd_HHmmss'); // e.g. 20250914_153045
    final timestamp = formatter.format(now);

    final filePath = '${externalDir?.path}/my_image_$timestamp.jpg';
    final file = File(filePath);
    await file.writeAsBytes(imageBytes);
    print("✅ Image saved at: $filePath");
    // App's cache directory
    final cacheDir = await getTemporaryDirectory();
    final filePath2 = '${cacheDir.path}/my_PDF_2_image_$timestamp.jpg';

    final file2 = File(filePath2);
    await file2.writeAsBytes(imageBytes);

    print("✅ Image saved at (cache): $filePath");
  }

  Future<void> getImage2() async {
    setState(() {
      message = "Processing PDF...";
      mlResult = "dummy job";
    });

    final image = await getImage3();

    if (image != null) {
      lastImageBytes = image.bytes;
      await saveImage(image.bytes);
      setState(() {
        message = "✅ Image saved successfully!";
      });
    } else {
      setState(() {
        message = "❌ Could not render image from PDF.";
      });
    }
  }

  Future<void> runML() async {
    if (lastImageBytes == null) {
      setState(() {
        mlResult = "❌ No image available. First save an image.";
      });
      return;
    }

    setState(() {
      mlResult = "Running ML...";
    });

    try {
      final mlHelper = MLHelper();

      // Call MLHelper method
      final externalDir = await getExternalStorageDirectory();
      final now = DateTime.now();
      final formatter = DateFormat('yyyyMMdd_HHmmss'); // e.g. 20250914_153045
      final timestamp = formatter.format(now);

      final filePath = '${externalDir?.path}/my_image_$timestamp.jpg';
      final file = File(filePath);
      final result = await mlHelper.textFromImage(
          file); //textFromImage(file);//final result = await MLHelper.textFromImage(file);
      print(result);
      setState(() {
        mlResult = result;
      });
    } catch (e) {
      setState(() {
        mlResult = "❌ Error: $e";
      });
    }
  }

  Future<PdfPageImage?> getImage3() async {
    // Let user pick a PDF file
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) {
      print("❌ No PDF selected");
      return null;
    }

    final String? pdfPath = result.files.single.path;
    if (pdfPath == null) {
      print("❌ Invalid file path");
      return null;
    }

    print("✅ Using PDF: $pdfPath");

    // Open PDF and render first page
    final document = await PdfDocument.openFile(pdfPath);
    final page = await document.getPage(1);

    final image = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.jpeg,
      backgroundColor: '#ffffff',
    );

    await page.close();
    await document.close();
    return image;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Convert PDF to Image & check it')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: getImage2,
              child: const Text("Save Image from PDF"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: runML,
              child: const Text("Run ML on Last Image"),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            Container(
              height: 200, // max height
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  mlResult,
                  style: const TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
