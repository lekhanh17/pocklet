import 'package:flutter/material.dart';

/// Tam thoi cho cac chuc nang chua lam trong dot nay.
void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature sẽ có ở đợt sau')));
}
