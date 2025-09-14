import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'camera_screen.dart';
import 'file_storage.dart';
import 'ml.dart';
import 'person.dart';
import 'result.dart';

class PictureScreen extends StatelessWidget {
  final XFile picture;
  final Person person;

  const PictureScreen(this.picture, this.person, {super.key});

  Future<void> copyFile(String sourcePath, String destinationPath) async {
    try {
      File sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) return;

      List<int> fileBytes = await sourceFile.readAsBytes();
      File destinationFile = File(destinationPath);
      await destinationFile.writeAsBytes(fileBytes);
      print('File copied: $destinationPath');
    } catch (e, st) {
      print('Error copying file: $e\n$st');
    }
  }

  Future<void> incrementCounter() async {
    try {
      int count = int.tryParse(person.age) ?? 0;
      count += 1;
      await FileStorage.writeCounter(count.toString(), 'counter2.txt');
      print('Counter incremented: $count');
    } catch (e, st) {
      print('Error incrementing counter: $e\n$st');
    }
  }

  Future<void> performOCR(BuildContext context) async {
    try {
      final image = File(picture.path);
      final helper = MLHelper();
      final result = await helper.textFromImage(image);

      try {
        await incrementCounter();
      } catch (e, st) {
        print('Error updating counter inside OCR: $e\n$st');
      }

      try {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ResultScreen(result, image)),
        );
      } catch (e, st) {
        print('Error navigating to ResultScreen: $e\n$st');
      }
    } catch (e, st) {
      print('Error performing OCR: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final deviceHeight = MediaQuery.of(context).size.height;

      return Scaffold(
        appBar: AppBar(title: const Text('Picture')),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
                'Image saved (you can OCR-analyse later)\nPath: ${picture.path}'),
            SizedBox(
              height: deviceHeight / 1.5,
              child: Image.file(
                File(picture.path),
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error\n$stackTrace');
                  return const Icon(Icons.broken_image,
                      size: 48, color: Colors.red);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  child: const Text('OCR (analyse now)'),
                  onPressed: () async {
                    await performOCR(context);
                  },
                ),
                ElevatedButton(
                  child: const Text('Go back (OCR later)'),
                  onPressed: () {
                    try {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => CameraScreen()),
                      );
                    } catch (e, st) {
                      print('Error navigating back to CameraScreen: $e\n$st');
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e, st) {
      print('Error building PictureScreen: $e\n$st');
      return Scaffold(
        appBar: AppBar(title: const Text('Picture')),
        body: Center(
          child: Text('Error loading screen: $e'),
        ),
      );
    }
  }
}
