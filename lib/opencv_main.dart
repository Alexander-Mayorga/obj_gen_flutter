import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'main.dart';
import 'src/objGen/src/native_cv.dart';
import 'package:image/image.dart' as img;

const title = 'Native OpenCV Example';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  getTemporaryDirectory().then((dir) => tempDir = dir);

  runApp(OpenCVApp());
}

class OpenCVApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _picker = ImagePicker();
  img.Image? image;
  bool _isProcessed = false;
  bool _isWorking = false;
  bool showSecondImage = false;
  Uint8List? imgData1;

  void showVersion() {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final snackbar = SnackBar(
      content: Text('OpenCV version: ${opencvVersion()}'),
    );

    scaffoldMessenger
      ..removeCurrentSnackBar(reason: SnackBarClosedReason.dismiss)
      ..showSnackBar(snackbar);
  }

  Future<String?> pickAnImage() async {
    if (Platform.isIOS || Platform.isAndroid) {
      return _picker
          .pickImage(
            source: ImageSource.gallery,
            imageQuality: 100,
          )
          .then((v) => v?.path);
    } else {
      return FilePicker.platform
          .pickFiles(
            dialogTitle: 'Pick an image',
            type: FileType.image,
            allowMultiple: false,
          )
          .then((v) => v?.files.first.path);
    }
  }

  Future<void> takeImageAndProcess() async {
    final imagePath = await pickAnImage();
    final data = await File(imagePath!).readAsBytes();
    image = img.decodeJpg(data);

    setState(() {
      _isWorking = true;
    });

    // Creating a port for communication with isolate and arguments for entry point
    final port = ReceivePort();
    final args = ProcessImageArguments(data, port.sendPort);

    // Spawning an isolate
    Isolate.spawn<ProcessImageArguments>(
      processImage,
      args,
      onError: port.sendPort,
      onExit: port.sendPort,
    );

    // Making a variable to store a subscription in
    late StreamSubscription sub;

    // Listening for messages on port
    sub = port.listen((_) async {
      print(_);
      // Cancel a subscription after message received called
      await sub.cancel();
      // List encodedJPG = img.encodeJpg(args.bytes);
      imgData1 = _;

      // print(imgData1![199]);
      setState(() {
        showSecondImage = true;
        _isProcessed = true;
        _isWorking = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        children: <Widget>[
          Center(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                if (_isProcessed && !_isWorking)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 3000, maxHeight: 300),
                    child: Image.file(
                      File(tempPath),
                      alignment: Alignment.center,
                    ),
                  ),
                Column(
                  children: [
                    ElevatedButton(
                      child: Text('Show version'),
                      onPressed: showVersion,
                    ),
                    ElevatedButton(
                      child: Text('Process photo'),
                      onPressed: takeImageAndProcess,
                    ),
                  ],
                ),
                showSecondImage
                    ? SizedBox(
                        height: 700, width: 700, child: Image.memory(imgData1!))
                    : Container()
              ],
            ),
          ),
          if (_isWorking)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(.7),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
