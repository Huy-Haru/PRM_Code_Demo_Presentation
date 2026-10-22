import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'todo.dart';

class TodoDatabase {
  TodoDatabase._();

  static final TodoDatabase instance = TodoDatabase._();

  static const _fileName = 'demo_todos.db';

  Future<Database>? _opening;

  /// Cache Future (không cache Database) để nhiều lời gọi đồng thời chỉ mở DB một lần.
  Future<Database> get _database => _opening ??= _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _fileName);
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute(
        'CREATE TABLE todos('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'title TEXT NOT NULL, '
        'done INTEGER NOT NULL DEFAULT 0)',
      ),
    );
  }

  /// Đường dẫn file .db (mở DB trước để chắc chắn file đã tồn tại).
  Future<String> filePath() async => (await _database).path;

  Future<int> count() async {
    final db = await _database;
    final rows = await db.rawQuery('SELECT COUNT(*) FROM todos');
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> clear() async {
    final db = await _database;
    await db.delete('todos');
  }

  /// Cách chậm: mỗi insert là một lần gọi qua cầu nối native và một transaction riêng.
  Future<void> insertOneByOne(List<Todo> todos) async {
    final db = await _database;
    for (final todo in todos) {
      await db.insert('todos', todo.toMap());
    }
  }

  /// Gom lệnh, commit một lần trong một transaction: lỗi giữa chừng thì rollback toàn bộ.
  Future<void> insertBatch(List<Todo> todos) async {
    final db = await _database;
    final batch = db.batch();
    for (final todo in todos) {
      batch.insert(
        'todos',
        todo.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
