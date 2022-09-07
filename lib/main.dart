import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:recursive_flutter/src/objGen/src/generate_obj.dart';

img.Image? image;
late Directory tempDir;
String get tempPath => '${tempDir.path}/temp.jpg';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  getTemporaryDirectory().then((dir) => tempDir = dir);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool showSecondImage = false;
  Uint8List? imgData1;
  late Uint8List imgData2;
  int highest = 0, lowest = 0;
  final picKey = GlobalKey();
  final _picker = ImagePicker();

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

  void floodFill(double xRatio, double yRatio) async {
    Uint8List data;
    ByteData bytes;

    String objFile;
    Uint8List imageBytes;
    GenerateOBJ obj1 = GenerateOBJ(10);

    // this is for web testing
    if (kIsWeb) {
      bytes = await rootBundle.load('images/pic4.jpg');
      image = img.decodeImage(bytes.buffer.asUint8List())!;

      int xClick = (image!.width * xRatio).floor();
      int yClick = (image!.height * yRatio).floor();

      imageBytes =
          await obj1.createOBJ(bytes.buffer.asUint8List(), xClick, yClick);
    } else {
      // This is for mobile
      final imagePath = await pickAnImage();
      data = await File(imagePath!).readAsBytes();
      image = img.decodeJpg(data);

      int xClick = (image!.width * xRatio).floor();
      int yClick = (image!.height * yRatio).floor();
      imageBytes = await obj1.createOBJ(data, xClick, yClick);
    }

    setState(() {
      showSecondImage = true;
      imgData1 = imageBytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                  child: Image.asset(
                    'assets/images/pic4.jpg',
                    key: picKey,
                  ),
                  onTapDown: (TapDownDetails details) {
                    double x = details.localPosition.dx /
                        picKey.currentContext!.size!.width;
                    double y = details.localPosition.dy /
                        picKey.currentContext!.size!.height;

                    floodFill(x, y);
                  }),
              showSecondImage
                  ? SizedBox(
                      height: 700, width: 700, child: Image.memory(imgData1!))
                  : Container()
            ],
          ),
        ),
      ),
    );
  }
}

class Vertex {
  double x;
  double y;
  double z;

  Vertex(this.x, this.y, this.z);
}
