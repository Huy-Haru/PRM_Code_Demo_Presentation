import 'package:flutter/material.dart';

import 'screens/file_demo_home.dart';

void main() => runApp(const FileDemoApp());

class FileDemoApp extends StatelessWidget {
  const FileDemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Module 9 • Câu 08–09',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF17365D)),
      scaffoldBackgroundColor: const Color(0xFFF4F7FB),
      useMaterial3: true,
    ),
    home: const FileDemoHome(),
  );
}
