@JS()
library opencv;

import 'dart:async';
import 'dart:typed_data';

import 'package:js/js.dart';
import 'package:js/js_util.dart';

// Allows use of the console.log method
// Ex: Viewing the properties of an OpenCV matrix
@JS('console.log')
external void _log(Object obj);

// This holds the OpenCV library as a Javascript object
@JS('cv')
external Object cv;

Future<Uint8List> houghCircles(
    Uint8List imageData, int rows, int cols, int type) async {
  // await for the opencv library promise
  final opencvOBJ = await promiseToFuture(cv);

  var circles = opencvOBJ.createNewMat();
  var gray = opencvOBJ.createNewMat();
  var blur = opencvOBJ.createNewMat();

  var color = opencvOBJ.createScalarThree(255, 0, 255);

  var imgMat = opencvOBJ.matFromArray(rows, cols, opencvOBJ.CV_8UC4, imageData);

  opencvOBJ.cvtColor(imgMat, gray, opencvOBJ.COLOR_RGBA2GRAY);
  opencvOBJ.medianBlur(gray, blur, 5);

  // these parameters of houghcircles is the same as in the c implementation
  // changing them could result in differences in accuracy or runtime
  opencvOBJ.HoughCircles(blur, circles, opencvOBJ.HOUGH_GRADIENT, 1,
      blur.rows / 16, 100, 30, 1, 20);

  // draw circles
  for (int i = 0; i < circles.cols; ++i) {
    var x = circles.data32F[i * 3];
    var y = circles.data32F[i * 3 + 1];
    var radius = circles.data32F[i * 3 + 2];
    var center = opencvOBJ.newPoint(x, y);
    opencvOBJ.circle(imgMat, center, radius, color, -1, opencvOBJ.FILLED);
  }

  // you need to copy the data from Javascript's Uint8Array to Dart's Uint8List
  Uint8List retData = Uint8List(imgMat.data.length);
  for (int i = 0; i < imgMat.data.length; i++) {
    retData[i] = imgMat.data[i];
  }

  return retData;
}
