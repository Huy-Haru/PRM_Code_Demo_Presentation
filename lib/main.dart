import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SQLite Sqflite Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TodoScreen(),
    );
  }
}

// ==========================================
// 1. MODEL CLASS
// ==========================================
class Todo {
  final int? id;
  final String title;
  final bool done;

  Todo({this.id, required this.title, this.done = false});

  // Ánh xạ từ Map (SQLite) sang Todo Object (Dart)
  factory Todo.fromMap(Map<String, Object?> row) {
    return Todo(
      id: row['id'] as int?,
      title: row['title'] as String,
      done: (row['done'] as int) == 1,
    );
  }

  // Chuyển Todo Object sang Map để Insert/Update vào SQLite
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'done': done ? 1 : 0,
    };
  }
}

// ==========================================
// 2. DATABASE HELPER (DATABASE MANAGEMENT)
// ==========================================
class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'todo_demo.db');
    
    // Mở CSDL bất đồng bộ (Trả về Future)
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
          "CREATE TABLE todos("
          "id INTEGER PRIMARY KEY AUTOINCREMENT, "
          "title TEXT NOT NULL, "
          "done INTEGER NOT NULL DEFAULT 0)",
        );
      },
    );
  }

  // Lấy danh sách Todos
  static Future<List<Todo>> getTodos() async {
    final db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'todos',
      orderBy: 'id DESC',
    );
    return rows.map((row) => Todo.fromMap(row)).toList();
  }

  // Thêm Todo mới
  static Future<int> insertTodo(String title) async {
    final db = await database;
    final todo = Todo(title: title);
    return await db.insert('todos', todo.toMap());
  }

  // Cập nhật trạng thái Done
  static Future<int> toggleTodoStatus(Todo todo) async {
    final db = await database;
    final updatedTodo = Todo(id: todo.id, title: todo.title, done: !todo.done);
    return await db.update(
      'todos',
      updatedTodo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  // Xóa Todo
  static Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// ==========================================
// 3. UI SCREEN
// ==========================================
class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final TextEditingController _controller = TextEditingController();

  void _addTodo() async {
    if (_controller.text.trim().isEmpty) return;
    await DatabaseHelper.insertTodo(_controller.text.trim());
    _controller.clear();
    setState(() {}); // Tải lại UI sau khi thêm
  }

  void _toggleTodo(Todo todo) async {
    await DatabaseHelper.toggleTodoStatus(todo);
    setState(() {}); // Tải lại UI sau khi update
  }

  void _deleteTodo(int id) async {
    await DatabaseHelper.deleteTodo(id);
    setState(() {}); // Tải lại UI sau khi xóa
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sqflite SQLite Demo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Nhập công việc mới...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addTodo,
                  child: const Text('Thêm'),
                ),
              ],
            ),
          ),
          Expanded(
            // Dùng FutureBuilder để hiển thị dữ liệu bất đồng bộ từ SQLite
            child: FutureBuilder<List<Todo>>(
              future: DatabaseHelper.getTodos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Lỗi: ${snapshot.error}'));
                }

                final todos = snapshot.data ?? [];
                if (todos.isEmpty) {
                  return const Center(child: Text('Chưa có công việc nào!'));
                }

                return ListView.builder(
                  itemCount: todos.length,
                  itemBuilder: (context, index) {
                    final todo = todos[index];
                    return ListTile(
                      leading: Checkbox(
                        value: todo.done,
                        onChanged: (_) => _toggleTodo(todo),
                      ),
                      title: Text(
                        todo.title,
                        style: TextStyle(
                          decoration: todo.done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTodo(todo.id!),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}