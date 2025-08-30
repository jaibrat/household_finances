// 📄 picture_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // for XFile

import 'file_storage.dart'; // contains FileStorage
// 👇 your own app files — adjust paths if needed
import 'ml.dart'; // contains MLHelper
import 'person.dart'; // contains Person
import 'result.dart'; // contains ResultScreen

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
    } catch (e) {
      print('Error copying file: $e');
    }
  }

  Future<void> incrementCounter() async {
    try {
      int count = int.tryParse(person.age) ?? 0;
      count += 1;
      await FileStorage.writeCounter(count.toString(), 'counter2.txt');
      print('Counter incremented: $count');
    } catch (e) {
      print('Error incrementing counter: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(title: const Text('Picture')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text('Path: ${picture.path}'),
          SizedBox(
            height: deviceHeight / 1.5,
            child: Image.file(File(picture.path)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                child: const Text('OCR'),
                onPressed: () async {
                  final image = File(picture.path);
                  final helper = MLHelper();
                  final result = await helper.textFromImage(image);

                  await FileStorage.writeCounter(
                      result, 'myFile${person.age}.txt');

                  await incrementCounter();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ResultScreen(result, image)),
                  );
                },
              ),
              ElevatedButton(
                child: const Text('Što je ovo?'),
                onPressed: () async {
                  final image = File(picture.path);
                  final helper = MLHelper();
                  final result = await helper.labelImage(image);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ResultScreen(result, image)),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
