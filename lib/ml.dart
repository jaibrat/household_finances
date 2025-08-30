import 'dart:io';

//import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'classifier.dart';

class MLHelper {
  Future<String> textFromImage2DE(File image) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(image);
    final recognizedText = await textRecognizer.processImage(inputImage);
    return recognizedText.text;
  }

  Future<String> textFromImageCleanDE(File image) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(image);
    final recognizedText = await textRecognizer.processImage(inputImage);

    final buffer = StringBuffer();

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        buffer.write(line.text); //buffer.write(line.text.trim());
      }
      // optional: if you want spacing *between blocks*:
      buffer.writeln();
    }

    await textRecognizer.close();
    return buffer.toString().trim();
  }

//args support android / Web , i don't have a mac

  Future<String> textFromImageDE3(File image) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(image);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();
    return recognizedText.text;
  }

  Future<List<List<String>>> extractTableFromImage(File image) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(image);
    final recognizedText = await textRecognizer.processImage(inputImage);

    List<List<String>> table = [];

    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        final words = line.elements.map((e) => e.text).toList();
        table.add(words);
      }
    }

    await textRecognizer.close();
    return table;
  }

  Future<String> textFromImage(File image) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(image);
    final recognizedText = await textRecognizer.processImage(inputImage);

    String tableTXT = "";

    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        final words = line.elements.map((e) => e.text).toString();
        tableTXT = tableTXT + words;
      }
    }

    await textRecognizer.close();
    return tableTXT;
  }

  Future<String> labelImage(File image) async {
    final inputImage = InputImage.fromFile(image);
    final options = ImageLabelerOptions(confidenceThreshold: 0.5);
    final imageLabeler = ImageLabeler(options: options);

    final labels = await imageLabeler.processImage(inputImage);
    String result = '';
    for (final label in labels) {
      result += '${label.index}: ${label.label} - ${label.confidence * 100}%\n';
    }
    return result;
  }

  Future<String> identifyLanguage(String text) async {
    final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
    final languages = await languageIdentifier.identifyPossibleLanguages(text);
    String result = '';
    for (final language in languages) {
      result +=
          'Language: ${language.languageTag} - Confidence: ${language.confidence * 100}%\n';
    }
    return result;
  }

  Future<String> classifyText(String message) async {
    final classifier = Classifier();
    final value = await classifier.classify(message);
    return value > 0 ? 'Positive sentiment' : 'Negative sentiment';
  }
}
