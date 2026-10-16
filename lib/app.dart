import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/strings_bn.dart';
import 'ui/home_screen.dart';

const Color kCrimson = Color(0xFFC62828);
const Color kEligibleGreen = Color(0xFF2E7D32);
const Color kWaitSlate = Color(0xFF64748B);

class RedGridApp extends StatelessWidget {
  const RedGridApp({super.key});

  ThemeData _theme(Brightness brightness) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kCrimson, brightness: brightness),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('bn'),
      supportedLocales: const [Locale('bn'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeScreen(),
    );
  }
}
