import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class Box2 {
  String txt;
  double xp;
  double yp;
  String tip;

  // constructor that takes four individual arguments and initializes the instance variables of the new Box2 object
  Box2(this.txt, this.xp, this.yp, this.tip);
  // Add this method
  Map<String, dynamic> toJson() => {
        "txt": txt,
        "xp": xp,
        "yp": yp,
        "tip": tip,
      };
}

Future<File?> getLastJsonTmpFile() async {
  final dir = await getApplicationDocumentsDirectory();

  // List all .jsonTMP files
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.jsonTMP'))
      .toList();

  if (files.isEmpty) return null;

  // Sort by last modified time descending
  files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

  // Return the most recently modified file
  return files.first;
}

Future<void> printLastJsonTmpFile() async {
  final file = await getLastJsonTmpFile();
  if (file == null) {
    print("No .jsonTMP files found.");
    return;
  }

  final content = await file.readAsString();
  print("Last .jsonTMP file: ${file.path}");
  print("Content:\n$content");
}

void DO_THIS() async {
  print("🔥 DO_THIS executed!");
  await printLastJsonTmpFile(); //just for debug
  print("🔥 done executed!");
  // TODO: put here the actual logic you want executed when called
}

double convertToNumeric(String input) {
  // remove all non-numeric characters from the input string
  String cleanedInput = input.replaceAll(RegExp(r'[^0-9.]'), '');

  try {
    // convert the cleaned input string to a double value
    return double.parse(cleanedInput);
  } catch (e) {
    // throw an exception if the cleaned input string cannot be converted to a double value
    throw Exception('Invalid numeric input: $input');
  }
}

/// Takes the original [File] image and the [RecognizedText]
/// from ML Kit, and returns a [ui.Image] with bounding boxes + numbers drawn.
Future<ui.Image> drawTextBoxesOnImage(
    File imageFile, RecognizedText recognizedText) async {
  // Load original image
  print('...............');
  print(imageFile.path);
  final this_is_the_image1 = imageFile.path;
  print('...............');
  final data = await imageFile.readAsBytes();
  final codec = await ui.instantiateImageCodec(data);
  final frame = await codec.getNextFrame();
  final originalImage = frame.image;

  // Create a canvas to draw on top of the image
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..color = Colors.red.withOpacity(0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  // Draw the original image first
  canvas.drawImage(originalImage, Offset.zero, Paint());

  // Text painter for numbering
  final textStyle = ui.TextStyle(
    color: Colors.yellow,
    fontSize: 10,
    background: Paint()..color = Colors.black.withOpacity(0.6),
  );

  int counter = 1; // numbering starts at 1

  // Draw bounding boxes + numbers for each line of text
  for (final block in recognizedText.blocks) {
    for (final line in block.lines) {
      final rect = line.boundingBox;
      if (rect != null) {
        // Draw rectangle
        canvas.drawRect(rect, paint);

        // Calculate middle point (x, y)
        final double centerX = rect.left + rect.width / 2;
        final double centerY = rect.top + rect.height / 2;

        // Draw number label in the middle
        final paragraphBuilder = ui.ParagraphBuilder(
          ui.ParagraphStyle(textAlign: TextAlign.center),
        )
          ..pushStyle(textStyle)
          ..addText(counter
              .toString()); //+' :' + centerX.toString() +',' +   centerY.toString());

        final paragraph = paragraphBuilder.build()
          ..layout(ui.ParagraphConstraints(width: rect.width));

        // Shift drawing to the center
        canvas.drawParagraph(
          paragraph,
          Offset(centerX - rect.width / 2, centerY - paragraph.height / 2),
        );

        counter++;
      }

      // Draw corner points (optional, still useful for debugging)
      for (final point in line.cornerPoints) {
        canvas.drawCircle(
          Offset(point.x.toDouble(), point.y.toDouble()),
          4,
          Paint()..color = Colors.blue,
        );
      }
    }
  }

  bool isMostlyNumbers(String input, {double threshold = 0.279}) {
    if (input.isEmpty) return false;

    final onlyDigits = RegExp(r'\d');
    int digitCount = onlyDigits.allMatches(input).length;
    int totalChars =
        input.replaceAll(RegExp(r'\s'), '').length; // ignore spaces

    if (totalChars == 0) return false;

    double ratio = digitCount / totalChars;
    return ratio >= threshold;
  }

  bool isNumericCurrencyDE(String input) {
    final trimmed = input.trim();

    // Regex:
    // ^\d+            → integer part (at least 1 digit)
    // ([.,]\d{1,2})?  → optional decimal part with 1–2 digits
    // \s*€?           → optional whitespace + euro sign
    // $
    final regex = RegExp(r'^\d+([.,]\d{1,2})?\s*€?$');

    return regex.hasMatch(trimmed);
  }

  bool isNumericCurrency(String input) {
    final trimmed = input.trim();

    // Regex:
    // ^\d+             → integer part (at least 1 digit)
    // ([.,]\d{2})      → decimal part with exactly 2 digits
    // \s*              → optional space(s)
    // (                → start currency group
    //   €              → literal €
    //   |EUR           → EUR (case-insensitive)
    //   |EURO          → EURO (case-insensitive)
    // )?               → group is optional
    // $                → end of string
    final regex = RegExp(
      r'^\d+([.,]\d{2})\s*(€|EUR|EURO)?$',
      caseSensitive: false, // so eur == EUR
    );

    return regex.hasMatch(trimmed);
  }

  bool hasTwoSeparatorsAnd25(String input) {
    final trimmed = input.trim();

    // Count occurrences of "/" and "."
    final slashCount = '/'.allMatches(trimmed).length;
    final dotCount = '.'.allMatches(trimmed).length;

    // Check if contains "25"
    final contains25 = trimmed.contains("25");

    // Condition: (two slashes OR two dots) AND has "25"
    return contains25 && (slashCount >= 2 || dotCount >= 2);
  }

  bool hasTwoSeparatorsAnd25b(String input) {
    final trimmed = input.trim();
    // Regex:
    // ([./]) → first separator character (either "/" or ".")
    // .*? → any characters between the first and second separator
    // [./] → second separator character (same as the first one)
    // .*25.* → at least one occurrence of "25" surrounded by any characters
    final regex = RegExp(r'([./]).*?[./].*25.*');
    return regex.hasMatch(trimmed);
  }

  DateTime? tryParseDateDE(String input) {
    final trimmed = input.trim();

    // Possible patterns to try
    final patterns = [
      "dd/MM/yy",
      "dd/MM/yyyy",
      "dd.MM.yy",
      "dd.MM.yyyy",
      "yyyy-MM-dd",
      "dd/MM/yy HH:mm",
      "dd.MM.yy HH:mm",
      "dd/MM/yyyy HH:mm",
      "dd.MM.yyyy HH:mm",
    ];

    for (final pattern in patterns) {
      try {
        return DateFormat(pattern).parseStrict(trimmed);
      } catch (_) {
        // ignore and try next
      }
    }
    return null; // not recognized
  }

  /// Cleans OCR string: removes extra spaces around separators
  String sanitizeDateInput(String input) {
    var s = input.trim();

    // Remove spaces around "/", ".", "-", ":"
    s = s.replaceAll(RegExp(r'\s*/\s*'), '/');
    s = s.replaceAll(RegExp(r'\s*\.\s*'), '.');
    s = s.replaceAll(RegExp(r'\s*-\s*'), '-');
    s = s.replaceAll(RegExp(r'\s*:\s*'), ':');

    // Collapse multiple spaces to single space
    s = s.replaceAll(RegExp(r'\s+'), ' ');

    return s;
  }

  /// Extract the first substring matching a given date pattern (basic regex)
  String? extractDateSubstring(String input, RegExp regex) {
    final match = regex.firstMatch(input);
    return match != null ? match.group(0) : null;
  }

  /// Try parsing multiple date formats after sanitizing input
  DateTime? tryParseDate(String input) {
    final sanitized = sanitizeDateInput(input);

    final patterns = [
      "dd/MM/yy",
      "dd/MM/yyyy",
      "dd.MM.yy",
      "dd.MM.yyyy",
      "yyyy-MM-dd",
      "dd/MM/yy HH:mm",
      "dd.MM.yy HH:mm",
      "dd/MM/yyyy HH:mm",
      "dd.MM.yyyy HH:mm",
    ];

    // Regex patterns to extract possible date substrings
    final regexPatterns = [
      RegExp(r'\d{1,2}/\d{1,2}/\d{2,4}(\s+\d{1,2}:\d{2})?'),
      RegExp(r'\d{1,2}\.\d{1,2}\.\d{2,4}(\s+\d{1,2}:\d{2})?'),
      RegExp(r'\d{4}-\d{1,2}-\d{1,2}'),
    ];

    String? datePart;
    for (final regex in regexPatterns) {
      datePart = extractDateSubstring(sanitized, regex);
      if (datePart != null) break; // use first match
    }

    if (datePart == null) return null;

    for (final pattern in patterns) {
      try {
        return DateFormat(pattern).parseStrict(datePart);
      } catch (_) {
        // ignore and try next
      }
    }

    return null; // not recognized
  }

  /// ---- Shared extractor so both Explorer & Search can use it ----
  bool? extractUkupnoValues2(String text) {
    // Regex for values with comma as decimal separator
    final regex = RegExp(r'\d{1,3},\d{2}');
    final matches = <double>[];

    final upperText = text.toUpperCase();

    // Find all keywords
    final idx1 = upperText.indexOf('UKUP');
    final idx2 = upperText.indexOf('TOTAL');
    final idx3 = upperText.indexOf('IZNO');
    final idx4 = upperText.indexOf('NAPLATA'); // new keyword

    // If none found, return empty list
    if (!(idx1 == -1 && idx2 == -1 && idx3 == -1 && idx4 == -1))
      return true;
    else
      return false;

    // Extract all matching values
  }

  void debugRecognizedText(RecognizedText recognizedText) async {
    double? minX, minY, maxX, maxY;
    int counter = 0; // numbering starts at 1
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final rect = line.boundingBox;

        if (rect != null) {
          // Track min/max
          minX = (minX == null)
              ? rect.left
              : rect.left < minX
                  ? rect.left
                  : minX;
          minY = (minY == null)
              ? rect.top
              : rect.top < minY
                  ? rect.top
                  : minY;
          maxX = (maxX == null)
              ? rect.right
              : rect.right > maxX
                  ? rect.right
                  : maxX;
          maxY = (maxY == null)
              ? rect.bottom
              : rect.bottom > maxY
                  ? rect.bottom
                  : maxY;

          // Print grouped text with position
          counter++;
          print("#" +
              counter.toString() +
              " TEXT: '${line.text}'  "
                  "X=${rect.left.toStringAsFixed(0)} "
                  "Y=${rect.top.toStringAsFixed(0)}");
        }
      }
    }

    print("----");
    print("Bounding box extremes:");
    print("minX=$minX, minY=$minY, maxX=$maxX, maxY=$maxY");
    print("Width=${(maxX! - minX!).toStringAsFixed(1)}, "
        "Height=${(maxY! - minY!).toStringAsFixed(1)}");
    final width = maxX - minX;
    final height = (maxY - minY);
    print("----");
    print("going agian :-)");
    counter = 0; // numbering starts at 1
    bool ima_datum = false;
    bool datum_uhvacen = false;
    int datum_counter = -1;
    double postotakX = 0;
    double postotakY = 0;
    double postotakX2 = 0;
    double postotakY2 = 0;
    DateTime? datum1 = DateFormat("yyyy-MM-dd").parse('1970-12-12');
    List<Box2>? boxes = [];
    List<Box2>? boxesMatch = [];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final rect = line.boundingBox;

        if (rect != null) {
          // Track min/max
          minX = (minX == null)
              ? rect.left
              : rect.left < minX
                  ? rect.left
                  : minX;
          minY = (minY == null)
              ? rect.top
              : rect.top < minY
                  ? rect.top
                  : minY;
          maxX = (maxX == null)
              ? rect.right
              : rect.right > maxX
                  ? rect.right
                  : maxX;
          maxY = (maxY == null)
              ? rect.bottom
              : rect.bottom > maxY
                  ? rect.bottom
                  : maxY;

          // Print grouped text with position
          counter++;
          bool added_box = false;

          postotakX = ((rect.left - minX) / width * 100.0);
          postotakY = ((rect.top - minY) / height * 100.0);
          final idx1 = line.text.toUpperCase().indexOf('UKUP');
          final idx2 = line.text.toUpperCase().indexOf('TOTAL');
          final idx3 = line.text.toUpperCase().indexOf('IZNO');
          if (!(idx1 == -1 && idx2 == -1 && idx3 == -1)) {
            ima_datum = true;
            datum_counter = counter;
            postotakX = ((rect.left - minX) / width * 100.0);
            postotakY = ((rect.top - minY) / height * 100.0);
          }
          if (isNumericCurrency(line.text)) {
            print("#" +
                counter.toString() +
                " NUM: '${line.text}'  "
                    "X=${((rect.left - minX) / width * 100.0).toStringAsFixed(1)}" +
                "% "
                    "Y=${((rect.top - minY) / height * 100.0).toStringAsFixed(1)}" +
                "%");
            //add to num.list NUM: '7,40'  X=82.5% Y=35.6%
            //Box2 box2 =
            if (!added_box) {
              boxes.add(Box2(line.text, postotakX, postotakY, 'NUM'));
              added_box = true;
            }
            ;
          } else {
            if (hasTwoSeparatorsAnd25(line.text)) {
              print("#" +
                  counter.toString() +
                  " DATE: '${line.text}'  "
                      "X=${((rect.left - minX) / width * 100.0).toStringAsFixed(1)}" +
                  "% "
                      "Y=${((rect.top - minY) / height * 100.0).toStringAsFixed(1)}" +
                  "%");
              if (hasTwoSeparatorsAnd25(line.text)) {
                print('b-kaže isto');
                datum_uhvacen = true; //popouštam
                datum1 = tryParseDate(line.text);
                if (!added_box) {
                  boxes.add(Box2(line.text, postotakX, postotakY, 'DATE'));
                  added_box = true;
                }
                ;
                //date
                postotakX2 = ((rect.left - minX) / width * 100.0);
                postotakY2 = ((rect.top - minY) / height * 100.0);
                if (((postotakX2 - postotakX).abs() < 10) ||
                    ((postotakY2 - postotakY).abs() < 10)) {
                  datum_uhvacen = true; //ovo je strože
                  print('C-kaže OK');
                }
              }
            } else {
              print("#" +
                  counter.toString() +
                  " TEXT: '${line.text}'  "
                      "X=${((rect.left - minX) / width * 100.0).toStringAsFixed(1)}" +
                  "% "
                      "Y=${((rect.top - minY) / height * 100.0).toStringAsFixed(1)}" +
                  "%");
              if (!added_box) {
                if (!isMostlyNumbers(line.text)) {
                  boxes.add(Box2(line.text, postotakX, postotakY, 'TEXT'));
                  added_box = true;
                }
              }
              ;
              //text --> daj što daš
            }
          }
        }
      }
    }
    //String? datum2; // declare a nullable string variable to hold the value of datum1
    // assign a value to datum1, or leave it as null if no value is available
    //datum2 = "1970-12-12";
    // check if datum1 has a value and print it, or print today's date if datum1 is null
    print('datum uhvaćen  $datum_uhvacen');
    String output_datum2;
    if (datum_uhvacen) {
      output_datum2 = datum1.toString(); // assign the value of datum1 to output
    } else {
      output_datum2 = DateFormat("yyyy-MM-dd").format(DateTime
          .now()); // format today's date as yyyy-MM-dd and assign it to output
      print('danas...');
    }
    print("----");
    print("datum");
    print(output_datum2); // print the final result
    print("----");
    print("datum");
    print("----");
    //printsomething();
    for (Box2 box in boxes) {
      print(
          'txt: ${box.txt}, xp: ${box.xp.toStringAsFixed(1)}, yp: ${box.yp.toStringAsFixed(1)}, tip: ${box.tip}');
    }
    //print(datum1.toString());
    print("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
    // print the values of each box in the array
    for (Box2 outerBox in boxes) {
      //print('Outer loop: txt: ${outerBox.txt}, xp: ${outerBox.xp}, yp: ${outerBox.yp}, tip: ${outerBox.tip}');
      // inner loop example using a different collection or condition
      for (Box2 innerbox in boxes) {
        //print('Inner loop iteration ');
        if ((outerBox.tip == "NUM") && (innerbox.tip == "TEXT")) {
          //okomito //smanjiti na 3%?
          if ((((innerbox.xp - outerBox.xp).abs() < 4)) &&
              (-45 < (innerbox.yp - outerBox.yp) &&
                  (innerbox.yp - outerBox.yp) < 0)) {
            print('Match found |: ${innerbox.txt} and ${outerBox.txt}');
            boxesMatch.add(Box2(innerbox.txt, 0, 0, outerBox.txt));
          }
          //vodoravno
          if ((((innerbox.yp - outerBox.yp).abs() < 3)) &&
              (-80 < (innerbox.xp - outerBox.xp) &&
                  (innerbox.xp - outerBox.xp) < 0)) {
            print('Match found -: ${innerbox.txt} and ${outerBox.txt}');
            boxesMatch.add(Box2(innerbox.txt, 0, 0, outerBox.txt));
          }
        }
        ;
      }
    }
    print('ništa više...');
    print('saving to file_DB');
    bool biggest = false;
    double naj_zasad = -0.1;
    for (Box2 box in boxesMatch) {
      // Find all keywords
      String upperText = box.txt.toUpperCase();
      final idx1 = upperText.indexOf('UKUP');
      final idx2 = upperText.indexOf('TOTAL');
      final idx3 = upperText.indexOf('IZNO');
      final idx4 = upperText.indexOf('NAPLATA');
      if (!(idx1 == -1 && idx2 == -1 && idx3 == -1 && idx4 == -1)) {
        //idemo
        //print('datum: ' + output_datum2);
        //print('Match_naziv: ${box.txt}');
        //print('Match_iznos: ${box.tip}');//znam da je ovo loša praksa programiranja
        if (naj_zasad < convertToNumeric(box.tip)) {
          //naj_zasad=double.parse(box.tip);
          //biggest=true;
          naj_zasad = convertToNumeric(box.tip);
        } else {
          //biggest=false;
        }
      }
    }
    for (Box2 box in boxesMatch) {
      // Find all keywords
      String upperText = box.txt.toUpperCase();
      final idx1 = upperText.indexOf('UKUP');
      final idx2 = upperText.indexOf('TOTAL');
      final idx3 = upperText.indexOf('IZNO');
      final idx4 = upperText.indexOf('NAPLATA');
      if (!(idx1 == -1 && idx2 == -1 && idx3 == -1 && idx4 == -1)) {
        if (naj_zasad == convertToNumeric(box.tip)) {
          //naj_zasad=double.parse(box.tip);
          //biggest=true;
          print('datum: ' + output_datum2);
          print('Match_naziv: ${box.txt}');
          print(
              'Match_iznos: ${box.tip}'); //znam da je ovo loša praksa programiranja
          // Prepare data as a Map

          // Get app documents directory
          final dir = await getApplicationDocumentsDirectory();
          final filePath =
              '${dir.path}/match_${DateTime.now().millisecondsSinceEpoch}.jsonTMP';
          final file = File(filePath);

          //try to see orig file of image
          final lastFile = await getLastJsonTmpFile();
          // Write JSON to file
          final data = {
            "datum": output_datum2, // your date
            "file_image": this_is_the_image1,
            ...box.toJson(), // all Box2 fields
          };
          //print('------');
          //print(data);
          //print('------');
          await file.writeAsString(jsonEncode(data));
          //await file.writeAsString(jsonEncode(box.toJson(), output_datum2));
          print("✅ Data saved to $filePath");
          break;
        } else {
          //biggest=false;
          //DO_THIS(); //DO_THIS!!!
        }
      }
    }
  }

  debugRecognizedText(recognizedText);

  // Convert drawing to an Image
  final picture = recorder.endRecording();
  final uiImage =
      await picture.toImage(originalImage.width, originalImage.height);

  return uiImage;
}

/// Helper to convert [ui.Image] to [Image] widget for display in Flutter
Future<Image> imageFromUiImage(ui.Image uiImage) async {
  final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();
  return Image.memory(bytes);
}
