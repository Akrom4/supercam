import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
      ),
    ),
  );
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.camera,
  });

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          FloatingActionButton(
            // Provide an onPressed callback.
            onPressed: () async {
              // Take the Picture in a try / catch block. If anything goes wrong,
              // catch the error.
              try {
                // Ensure that the camera is initialized.
                await _initializeControllerFuture;

                // Attempt to take a picture and get the file `image`
                // where it was saved.
                final image = await _controller.takePicture();

                if (!mounted) return;

                // If the picture was taken, display it on a new screen.
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DisplayPictureScreen(
                      // Pass the automatically generated path to
                      // the DisplayPictureScreen widget.
                      imagePath: image.path,
                    ),
                  ),
                );
              } catch (e) {
                // If an error occurs, log the error to the console.
                print(e);
              }
            },
            child: const Icon(Icons.camera_alt),
          ),
          FloatingActionButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const PhotoListScreen()),
              );
            },
            child: const Icon(Icons.photo_library),
          ), // Floating action button to display the photo list
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

// A widget that displays the list of photos taken by the user.
class PhotoListScreen extends StatefulWidget {
  const PhotoListScreen({super.key});
  @override
  PhotoListScreenState createState() => PhotoListScreenState();
}

class PhotoListScreenState extends State<PhotoListScreen> {
  late Future<List<String>> _photoListFuture;

  @override
  void initState() {
    super.initState();
    _photoListFuture = _getPhotoList();
  }

  Future<List<String>> _getPhotoList() async {
    final directory = await getApplicationDocumentsDirectory();
    List<FileSystemEntity> files = directory.listSync();
    List<String> photoList = [];

    for (FileSystemEntity file in files) {
      if (file.path.endsWith('.jpg')) {
        photoList.add(file.path);
      }
    }

    return photoList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo List')),
      body: FutureBuilder<List<String>>(
        future: _photoListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error'));
            } else if (snapshot.hasData) {
              return ListView.builder(
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  String fileName = path.basename(snapshot.data![index]);
                  String filePath = snapshot.data![index];

                  return ListTile(
                    leading: Image.file(File(filePath)),
                    title: Text(fileName),
                    onTap: () {
                      // Navigate to the FullPhotoScreen, passing the file path
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              FullPhotoScreen(imagePath: filePath),
                        ),
                      );
                    },
                  );
                },
              );
            } else {
              return const Center(child: Text('No photos'));
            }
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;

  const DisplayPictureScreen({super.key, required this.imagePath});

  @override
  DisplayPictureScreenState createState() => DisplayPictureScreenState();
}

class DisplayPictureScreenState extends State<DisplayPictureScreen> {
  Future<void> _saveImage(String newName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final name =
          newName.isNotEmpty ? newName : path.basename(widget.imagePath);
      final newFilePath = path.join(directory.path, name);

      // This will either successfully return a File or throw an error
      await File(widget.imagePath).copy(newFilePath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo saved as $name')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save photo')),
      );
      Navigator.pop(context);
    }
  }

  Future<String> _getNextFileName() async {
    final directory = await getApplicationDocumentsDirectory();
    int fileNumber = 1;

    while (true) {
      String fileName = 'supercam${fileNumber.toString().padLeft(3, '0')}.jpg';
      File file = File('${directory.path}/$fileName');
      if (!await file.exists()) {
        fileName = fileName.substring(0, fileName.length - 4);
        return fileName;
      }
      fileNumber++;
    }
  }

  Future<String?> _askFileName(BuildContext context) async {
    // Get the next available file name
    String defaultFileName = await _getNextFileName();
    TextEditingController fileNameController =
        TextEditingController(text: defaultFileName);

    // A flag to check if the widget is still in the widget tree
    bool isWidgetMounted = true;

    String? selectedFileName = await showDialog<String?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Enter File Name'),
          content: TextField(
            controller: fileNameController,
            decoration: const InputDecoration(hintText: "File name"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                if (isWidgetMounted) {
                  Navigator.of(dialogContext).pop(); // Pop without value
                }
              },
            ),
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                if (isWidgetMounted) {
                  Navigator.of(dialogContext).pop(fileNameController.text);
                }
              },
            ),
          ],
        );
      },
    );

    // When the dialog is closed, set the flag to false
    isWidgetMounted = false;
    selectedFileName = '$selectedFileName.jpg';

    return selectedFileName; // Will be null if the dialog was cancelled
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      body: Image.file(File(widget.imagePath)),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          // Cross button to discard the photo
          FloatingActionButton(
            onPressed: () => Navigator.pop(context),
            backgroundColor: Colors.red,
            child: const Icon(Icons.close),
          ),
          // Check button to save the photo
          FloatingActionButton(
            onPressed: () async {
              String? fileName = await _askFileName(context);
              if (fileName != null) {
                await _saveImage(fileName);
              }
            },
            backgroundColor: Colors.green,
            child: const Icon(Icons.check),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class FullPhotoScreen extends StatelessWidget {
  final String imagePath;

  const FullPhotoScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Full Photo')),
      body: Center(
        child: Image.file(File(imagePath)),
      ),
    );
  }
}
