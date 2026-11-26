import 'package:flutter/foundation.dart';

/// Cau bao loi cho nguoi dung.
/// - ArgumentError: loi kiem tra du lieu, da viet san bang tieng Viet (vi du
///   "Số tiền phải từ 1 đến 1.000.000.000 ₫") nen hien nguyen van.
/// - Loi khac (mang, server, loi lap trinh): ban release chi hien cau chung,
///   khong lo chi tiet ky thuat; ban debug hien day du de de sua.
String friendlyError(Object error) {
  if (error is ArgumentError && error.message is String) {
    return error.message as String;
  }
  return kDebugMode ? '$error' : 'Kiểm tra kết nối mạng rồi thử lại.';
}
