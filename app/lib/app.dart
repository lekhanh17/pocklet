import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/shell/home_shell.dart';

class PockletApp extends StatelessWidget {
  const PockletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocklet',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeShell(),
    );
  }
}
