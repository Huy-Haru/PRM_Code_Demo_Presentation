import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _keyDarkMode = 'is_dark_mode';
  final SharedPreferences _prefs;
  late bool _isThemeMode;

  bool get isThemeMode => _isThemeMode;
  ThemeMode get themeMode => _isThemeMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider(this._prefs) {
    _isThemeMode = _prefs.getBool(_keyDarkMode) ?? false;
  }

  void toggleTheme(bool value) {
    if (_isThemeMode == value) return;
    _isThemeMode = value;
    notifyListeners();
    _prefs.setBool(_keyDarkMode, value);
  }
}

void main() async {
  // [KHÁC BIỆT 2] Chờ đọc xong ổ cứng mới cho phép runApp
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(prefs),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Demo Theme')),
      body: Center(
        child: Switch(
          value: themeProvider.isThemeMode,
          onChanged: (val) => context.read<ThemeProvider>().toggleTheme(val),
        ),
      ),
    );
  }
}
