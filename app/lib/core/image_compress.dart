import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// BR-05: nen ve canh dai toi da 1280 px, JPEG chat luong 80, toi da 2 MB.
const maxPhotoSide = 1280;
const photoQuality = 80;
const maxPhotoBytes = 2 * 1024 * 1024;

/// Nen anh truoc khi tai len. Chay tren isolate rieng de khong giat giao dien.
/// Tra ve file JPEG moi nam canh file goc.
Future<File> compressPhoto(String sourcePath) async {
  final bytes = await File(sourcePath).readAsBytes();
  final output = await compute(_compressBytes, bytes);
  final target = File('$sourcePath.pocklet.jpg');
  return target.writeAsBytes(output, flush: true);
}

Uint8List _compressBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('File không phải ảnh JPEG hoặc PNG');
  }
  // Xoay anh theo EXIF truoc khi thu nho
  var image = img.bakeOrientation(decoded);
  final longest = math.max(image.width, image.height);
  if (longest > maxPhotoSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxPhotoSide)
        : img.copyResize(image, height: maxPhotoSide);
  }

  // Hiem khi vuot 2 MB o 1280 px; neu co thi giam chat luong dan
  var quality = photoQuality;
  var output = img.encodeJpg(image, quality: quality);
  while (output.length > maxPhotoBytes && quality > 40) {
    quality -= 10;
    output = img.encodeJpg(image, quality: quality);
  }
  if (output.length > maxPhotoBytes) {
    throw StateError('Ảnh lớn hơn 2 MB sau khi nén');
  }
  return output;
}