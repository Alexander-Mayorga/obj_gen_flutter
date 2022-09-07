import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as imgLib;
import 'package:path_provider/path_provider.dart';

import 'opencv.dart';

class GenerateOBJ {
  int segmentations;

  GenerateOBJ(this.segmentations);

  /// Takes in an Uint8List jpg information, an x and y to begin the region growing process.
  /// Returns a string that contains the OBJ file.
  Future<Uint8List> createOBJ(Uint8List imageData, int x, int y) async {
    imgLib.Image img = imgLib.decodeJpg(imageData)!;
    imgLib.Image imgWeb = imgLib.decodeJpg(imageData)!;
    imgLib.adjustColor(img, brightness: .4);
    imgLib.sobel(img);
    imgLib.adjustColor(img, exposure: 2);
    imgLib.gaussianBlur(img, 2);
    imgLib.invert(img);
    Uint8List byteData = img.getBytes();

    for (int i = 0; i < byteData.length; i = i + 4) {
      int j = i;
      if (byteData[j] > 170 && byteData[j + 1] > 170 && byteData[j + 2] > 170) {
        // rgba
        byteData[j] = 255;
        byteData[j + 1] = 255;
        byteData[j + 2] = 255;
        byteData[j + 3] = 255;
      } else {
        // rgba
        byteData[j] = 0;
        byteData[j + 1] = 0;
        byteData[j + 2] = 0;
        byteData[j + 3] = 255;
      }
    }
    // find quarter and its size

    // we only need quarter data if we are on web
    // we need to pass pixel data
    Uint8List quarterData;
    imgLib.Image quarterImg;
    if (kIsWeb) {
      quarterData =
          await houghCircles(imgWeb.getBytes(), img.height, img.width, 0);

      quarterImg = imgLib.Image.fromBytes(img.width, img.height, quarterData,
          format: imgLib.Format.rgba);
    } else {
      quarterData = await houghCircles(imageData, img.height, img.width, 0);
      quarterImg = imgLib.decodeJpg(quarterData)!;
    }

    // perform region growing
    _recursiveGrowUp(x, y, img);
    _recursiveGrowDown(x, y + 1, img);

    // find height of the region expanded area
    bool foundFirstGreen = false, foundfirstPink = false;

    int highest = 0, lowest = 0;
    int highestPink = 0, lowestPink = 0;

    for (int i = 0; i < img.height; i++) {
      for (int j = 0; j < img.width; j++) {
        int quarterPixel = quarterImg.getPixel(j, i);
        if (quarterPixel == 0xFF00FF || quarterPixel == 0xFFFF00FF) {
          if (foundfirstPink) {
            if (i >= highestPink) {
              highestPink = i;
            }
          } else {
            lowestPink = i;
            highestPink = i;
            foundfirstPink = true;
          }
        }

        if (img.getPixel(j, i) != 4281980459) {
          img.setPixel(j, i, 4294967295);
        } else {
          if (foundFirstGreen) {
            if (i >= highest) {
              highest = i;
            }
          } else {
            lowest = i;
            highest = i;
            foundFirstGreen = true;
          }
        }
      }
    }

    int diameter = highestPink - lowestPink;

    double MillimetersOverPixels;

    if (diameter != 0) {
      MillimetersOverPixels = 24.26 / diameter.abs();
    } else {
      MillimetersOverPixels = 1;
    }

    // get height and segment
    // double difference = (highest - lowest) * MillimetersOverPixels;
    // double startY = difference.abs() * -1 / 2;
    // int interval = (difference / segmentations).truncate();
    int pixelInterval = ((highest - lowest) / segmentations).truncate();

    img = imgLib.sobel(img);

    List<Vertex> verts = [];

    int currentHeight = lowest;

    for (int i = 0; i < segmentations; i++) {
      bool foundFirstEdge = false;
      int leftPixel = 0, rightPixel = 0;

      for (int j = 0; j < img.width; j++) {
        if (img.getPixel(j, currentHeight) == 0xFFFFFFFF) {
          if (!foundFirstEdge) {
            leftPixel = j;
            foundFirstEdge = true;
          } else {
            rightPixel = j;
          }
        }
      }
      // create a circle here
      // left: left side of arm
      // right: right most side of arm
      // equation for circle: (x-h)^2 + (y-k)^2 = r^2
      // we have x, so we solve for y:
      //  y = sqrt(r^2 - x^2)
      double leftMilli = leftPixel * MillimetersOverPixels;
      double rightMilli = rightPixel * MillimetersOverPixels;

      double acrossDistanceMilli = (rightMilli - leftMilli);

      double interval = acrossDistanceMilli / 4;
      double radius = acrossDistanceMilli / 2;

      double xCenter = leftMilli + radius;
      double milliY = currentHeight * MillimetersOverPixels;

      verts.add(Vertex(leftMilli, milliY, 0));

      //TODO: Optimize using indices
      for (int count = 0; count < 4; count++) {
        double x = leftMilli + interval * (count + 1);
        double y = sqrt(radius * radius - pow(x - xCenter, 2));
        if (y.isNaN) y = 0.0;
        verts.add(Vertex(x, milliY, y));
      }

      for (int count = 0; count < 3; count++) {
        double x = rightMilli - (interval * (count + 1));
        double y = sqrt(radius * radius - pow(x - xCenter, 2));

        if (y.isNaN) y = 0.0;
        verts.add(Vertex(x, milliY, -y));
      }
      currentHeight += pixelInterval;
    }

    // for (int i = lowest; i < highest; i += interval) {
    //   bool foundFirst = false;
    //   double left = 0, right = 0;

    //   for (int j = 0; j < img.width; j++) {
    //     if (img.getPixel(j, i) == 0xFFFFFFFF) {
    //       if (!foundFirst) {
    //         left = j.toDouble() * MillimetersOverPixels;
    //         foundFirst = true;
    //       } else {
    //         right = j.toDouble() * MillimetersOverPixels;
    //       }
    //     }
    //   }

    //   // create a circle here
    //   // left: left side of arm
    //   // right: right most side of arm
    //   // equation for circle: (x-h)^2 + (y-k)^2 = r^2
    //   // we have x, so we solve for y:
    //   //  y = sqrt(r^2 - x^2)
    //   double distance = (right - left) * MillimetersOverPixels;

    //   double interval = distance / 4;
    //   double radius = distance / 2;

    //   double xCenter = left + radius;

    //   verts.add(Vertex(left, startY, 0));

    //   //TODO: Optimize using indices
    //   for (int count = 0; count < 4; count++) {
    //     double x = left + interval * (count + 1);
    //     double y = sqrt(radius * radius - pow(x - xCenter, 2));
    //     if (y.isNaN) y = 0.0;
    //     verts.add(Vertex(x, startY, y));
    //   }

    //   for (int count = 0; count < 3; count++) {
    //     double x = right - (interval * (count + 1));
    //     double y = sqrt(radius * radius - pow(x - xCenter, 2));
    //     if (y.isNaN) y = 0.0;
    //     verts.add(Vertex(x, startY, -y));
    //   }

    //   startY += interval;
    // }

    // This will hold the obj file
    String contents = "# Flutter OBJ File: \n";

    // TODO: Need to work on centering objs and sizing
    for (int count = 0; count < verts.length; count++) {
      contents +=
          "v ${(verts[count].x) / 1000} ${(verts[count].y) / 1000} ${verts[count].z / 1000}\n";
    }

    for (int i = 0; i < (verts.length / 8) - 1; i++) {
      int firstCircle = 0 + i * 8;
      int secondCircle = 8 + i * 8;
      int endFirstCircle = firstCircle + 7;
      int endSecondCircle = secondCircle + 7;
      int index1, index2, index3;

      // this connects the vertices of one circle to another
      while (firstCircle != endFirstCircle && secondCircle != endSecondCircle) {
        index1 = firstCircle;
        index2 = secondCircle;
        secondCircle++;
        index3 = secondCircle;
        contents += "f ${index1 + 1} ${index2 + 1} ${index3 + 1}\n";
        index1 = firstCircle;
        firstCircle++;
        index2 = firstCircle;
        index3 = secondCircle;
        contents += "f ${index1 + 1} ${index2 + 1} ${index3 + 1}\n";
      }

      index1 = firstCircle;
      index2 = secondCircle;
      secondCircle++;
      index3 = secondCircle - 8;
      contents += "f ${index1 + 1} ${index2 + 1} ${index3 + 1}\n";
      index1 = firstCircle;
      firstCircle++;
      index2 = firstCircle - 8;
      index3 = secondCircle - 8;
      contents += "f ${index1 + 1} ${index2 + 1} ${index3 + 1}\n";
    }

    if (!kIsWeb) {
      final directory = await getExternalStorageDirectory();
      final file = File('${directory!.path}/test1.txt');

      await file.writeAsString(contents);
    } else {
      print(contents);
    }

    return imgLib.encodeJpg(img) as Uint8List;
  }

  void _recursiveGrowUp(int x, int y, imgLib.Image image) {
    if (x >= image.width || x <= 0 || y >= image.height || y <= 0) {
      return;
    }

    int pixel = image.getPixel(x, y);

    if (pixel != 4294967295) {
      return;
    }

    image.setPixel(x, y, 4281980459);
    _recursiveGrowUp(x + 1, y, image);
    _recursiveGrowUp(x, y - 1, image);
    _recursiveGrowUp(x - 1, y, image);
  }

  void _recursiveGrowDown(int x, int y, imgLib.Image image) {
    if (x >= image.width || x <= 0 || y >= image.height || y <= 0) {
      return;
    }
    int pixel = image.getPixel(x, y);
    if (pixel > 4286578687) {
      pixel = 4294967295;
    } else {
      pixel = 4278190080;
    }
    if (pixel != 4294967295) {
      return;
    }
    image.setPixel(x, y, 4281980459);
    _recursiveGrowDown(x - 1, y, image);
    _recursiveGrowDown(x, y + 1, image);
    _recursiveGrowDown(x + 1, y, image);
  }
}

class Vertex {
  double x;
  double y;
  double z;

  Vertex(this.x, this.y, this.z);
}
