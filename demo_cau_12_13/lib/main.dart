import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

const int schemaVersion = int.fromEnvironment('DB_VERSION', defaultValue: 2);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class User {
  final int id;
  final String name;
  final String? email;
  final String? phoneNumber;

  const User({required this.id, required this.name, this.email, this.phoneNumber});

  factory User.fromMap(Map<String, Object?> row) => User(
        id: row['id'] as int,
        name: row['name'] as String,
        email: row['email'] as String?,
        phoneNumber: row['phone_number'] as String?,
      );
}

class UserDatabase {
  UserDatabase._();
  static final UserDatabase instance = UserDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw StateError('DB_VERSION must be 1 or 2');
    }
    final directory = await getDatabasesPath();
    final path = join(directory, 'users_migration_demo.db');
    _database = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT${version >= 2 ? ', phone_number TEXT' : ''}
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE Users ADD COLUMN phone_number TEXT');
        }
      },
    );
    return _database!;
  }

  Future<List<User>> getUsers() async {
    final db = await database;
    final rows = await db.query('Users', orderBy: 'id DESC');
    return rows.map((row) => User.fromMap(row)).toList();
  }

  Future<void> addUser(String name, String email) async {
    final db = await database;
    await db.insert('Users', {'name': name, 'email': email});
  }

  Future<void> setPhone(int id, String phone) async {
    if (schemaVersion < 2) return;
    final db = await database;
    await db.update('Users', {'phone_number': phone}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> inspectColumns() async {
    final db = await database;
    return db.rawQuery('PRAGMA table_info(Users)');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'sqflite: Questions 12 & 13',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo), useMaterial3: true),
        home: const UsersPage(),
      );
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<List<User>> usersFuture;
  late Future<List<Map<String, Object?>>> columnsFuture;
  int count = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      usersFuture = UserDatabase.instance.getUsers();
      columnsFuture = UserDatabase.instance.inspectColumns();
    });
  }

  Future<void> _add() async {
    try {
      count++;
      await UserDatabase.instance.addUser('Người dùng $count', 'user$count@example.com');
      if (mounted) _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _setPhone(User user) async {
    try {
      await UserDatabase.instance.setPhone(user.id, '0901234567');
      if (mounted) _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('SQLite schema v$schemaVersion'), actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh), tooltip: 'Tải lại'),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add, icon: const Icon(Icons.add), label: const Text('Thêm User')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: columnsFuture,
              builder: (context, snapshot) => Text(
                snapshot.hasData
                    ? 'Cột của Users: ${snapshot.data!.map((c) => c['name']).join(', ')}'
                    : snapshot.hasError ? 'Lỗi đọc schema: ${snapshot.error}' : 'Đang đọc schema...',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('Câu 12: db.query → List<Map> → User.fromMap → FutureBuilder → ListView',
                textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: FutureBuilder<List<User>>(
              future: usersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Truy vấn lỗi: ${snapshot.error}'));
                }
                final users = snapshot.data ?? [];
                if (users.isEmpty) {
                  return const Center(child: Text('Chưa có user. Nhấn Thêm User.'));
                }
                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text('${user.id} — ${user.name}'),
                        subtitle: Text('${user.email ?? ""}\nSĐT: ${user.phoneNumber ?? "NULL"}'),
                        isThreeLine: true,
                        trailing: schemaVersion >= 2
                            ? IconButton(
                                tooltip: 'Thêm số điện thoại',
                                onPressed: () => _setPhone(user),
                                icon: const Icon(Icons.phone),
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
}
