import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SharedPreferencesDemo(),
  ));
}

class SharedPreferencesDemo extends StatefulWidget {
  const SharedPreferencesDemo({super.key});

  @override
  State<SharedPreferencesDemo> createState() => _SharedPreferencesDemoState();
}

class _SharedPreferencesDemoState extends State<SharedPreferencesDemo> {
  // Biến lưu trữ giá trị trên UI
  String _savedUsername = 'Chưa có dữ liệu';
  final TextEditingController _controller = TextEditingController();
  static const String _usernameKey = 'username_key';

  @override
  void initState() {
    super.initState();
    _readData(); // Đọc dữ liệu đã lưu ngay khi mở màn hình
  }

  // 1. ĐỌC DỮ LIỆU (READ)
  Future<void> _readData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedUsername = prefs.getString(_usernameKey) ?? 'Chưa có dữ liệu';
    });
  }

  // 2. GHI DỮ LIỆU (WRITE)
  Future<void> _writeData() async {
    if (_controller.text.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, _controller.text);

    _controller.clear();
    await _readData(); // Đọc lại dữ liệu để cập nhật UI
  }

  // 3. XÓA DỮ LIỆU (DELETE)
  Future<void> _deleteData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);

    await _readData(); // Đọc lại để cập nhật trạng thái UI
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo CRUD SharedPreferences'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Nhập tên người dùng',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _writeData,
              child: const Text('Ghi dữ liệu (Write)'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _deleteData,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Xóa dữ liệu (Delete)', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Dữ liệu hiện tại trong SharedPreferences:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _savedUsername,
              style: const TextStyle(fontSize: 18, color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}