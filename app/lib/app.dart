import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
      // Giao dien tieng Viet, ke ca hop chon ngay gio cua Material
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeShell(),
    );
  }
}