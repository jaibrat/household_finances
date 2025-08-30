// camera_screen.dart
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'person.dart';
import 'picture_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final ImagePicker _picker = ImagePicker();

  Directory? currentDir;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    await _initializeControllerFuture;
    final image = await _controller!.takePicture();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PictureScreen(image, Person("John Doe", "35")),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null) {
      for (final xFile in images) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PictureScreen(xFile, Person("John Doe", "35")),
          ),
        );
      }
    }
  }

  Future<void> _pickFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result != null) {
      for (final file in result.files) {
        if (file.path != null) {
          final xFile = XFile(file.path!);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PictureScreen(xFile, Person("John Doe", "35")),
            ),
          );
        }
      }
    }
  }

  /// Open cache explorer
  Future<void> _openCacheExplorer() async {
    final dir = await getTemporaryDirectory();
    setState(() => currentDir = dir);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text("Go Back"),
          ),
          body: CacheExplorer(initialDir: dir),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null)
      return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text("Camera")),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(_controller!);
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.large(
                onPressed: _takePicture,
                heroTag: 'camera',
                tooltip: 'Camera',
                child: const Icon(Icons.camera_alt, size: 36),
              ),
              const SizedBox(height: 4),
              const Text("Take-picture"),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                onPressed: _pickFromGallery,
                heroTag: 'gallery',
                backgroundColor: Colors.blue,
                tooltip: 'Gallery',
                child: const Icon(Icons.photo_library),
              ),
              const SizedBox(height: 4),
              const Text("Gallery"),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                onPressed: _pickFromFiles,
                heroTag: 'files',
                backgroundColor: Colors.green,
                tooltip: 'Files',
                child: const Icon(Icons.folder_open),
              ),
              const SizedBox(height: 4),
              const Text("Files"),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton(
                onPressed: _openCacheExplorer,
                heroTag: 'cache',
                backgroundColor: Colors.purple,
                tooltip: 'Cache Explorer',
                child: const Icon(Icons.folder),
              ),
              const SizedBox(height: 4),
              const Text("Cache"),
            ],
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

/// Explorer widget for cache
class CacheExplorer extends StatefulWidget {
  final Directory initialDir;

  const CacheExplorer({super.key, required this.initialDir});

  @override
  State<CacheExplorer> createState() => _CacheExplorerState();
}

class _CacheExplorerState extends State<CacheExplorer> {
  late Directory currentDir;

  @override
  void initState() {
    super.initState();
    currentDir = widget.initialDir;
  }

  void _goUp() {
    if (currentDir.parent.path != currentDir.path) {
      setState(() {
        currentDir = currentDir.parent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = currentDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.jpg') || f.path.endsWith('.*'))
        .toList();

    final folders = currentDir.listSync().whereType<Directory>().toList();

    return Column(
      children: [
        Container(
          color: Colors.grey[300],
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                onPressed: _goUp,
                icon: const Icon(Icons.arrow_upward),
              ),
              Expanded(child: Text(currentDir.path)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              ...folders.map((f) => ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(f.path.split('/').last),
                    onTap: () => setState(() => currentDir = f),
                  )),
              ...items.map((f) => ListTile(
                    leading: const Icon(Icons.image),
                    title: Text(f.path.split('/').last),
                    onTap: () {
                      final xFile = XFile(f.path);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PictureScreen(xFile, Person("John Doe", "35")),
                        ),
                      );
                    },
                  )),
            ],
          ),
        ),
      ],
    );
  }
}
