import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// BR-05: nen ve canh dai toi da 1280 px, JPEG chat luong 80, toi da 2 MB.
const maxPhotoSide = 1280;
const photoQuality = 80;
const maxPhotoBytes = 2 * 1024 * 1024;

/// Truyen cho image_picker (maxWidth / maxHeight): Android tu giai ma bang
/// he dieu hanh va tra ve JPEG da thu nho. Nho vay:
/// - anh HEIC (nhieu may Samsung, Pixel luu mac dinh) doi thanh JPEG, goi `image`
///   (thuan Dart) khong doc duoc HEIC;
/// - khong phai giai ma anh 12 MP bang Dart, nen nhanh hon nhieu.
const double pickerMaxSide = 1280;

/// Anh hong hoac dinh dang khong ho tro: thu lai cung khong duoc, khac voi loi mang.
class PhotoUnreadableException implements Exception {
  const PhotoUnreadableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Nen anh truoc khi tai len. Chay tren isolate rieng de khong giat giao dien.
/// Tra ve file JPEG moi nam canh file goc.
/// Nem [PhotoUnreadableException] neu anh khong doc duoc hoac van qua 2 MB.
Future<File> compressPhoto(String sourcePath) async {
  final bytes = await File(sourcePath).readAsBytes();
  final output = await compute(_compressBytes, bytes);
  if (output == null) {
    throw const PhotoUnreadableException('Ảnh không đọc được hoặc định dạng không hỗ trợ');
  }
  final target = File('$sourcePath.pocklet.jpg');
  return target.writeAsBytes(output, flush: true);
}

/// Tra ve null neu anh khong dung duoc (thay vi nem loi qua isolate).
Uint8List? _compressBytes(Uint8List bytes) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    // File hong: goi image co the nem loi thay vi tra null
    return null;
  }
  if (decoded == null) return null;

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
  return output.length > maxPhotoBytes ? null : output;
}
