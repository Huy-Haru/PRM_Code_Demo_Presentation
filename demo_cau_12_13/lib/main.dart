
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// Chọn V1 hoặc V2 khi chạy ứng dụng.
const int schemaVersion = int.fromEnvironment(
  'DB_VERSION',
  defaultValue: 2,
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

// ==========================================
// 1. USER MODEL - CÂU 12
// ==========================================

class User {
  final int id;
  final String name;
  final String? email;
  final String? phoneNumber;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.phoneNumber,
  });

  // Chuyển dữ liệu Map thành User Object.
  factory User.fromMap(Map<String, Object?> row) {
    return User(
      id: row['id'] as int,
      name: row['name'] as String,
      email: row['email'] as String?,
      phoneNumber: row.containsKey('phone_number')
          ? row['phone_number'] as String?
          : null,
    );
  }
}

// ==========================================
// 2. SQLITE DATABASE - CÂU 12 & 13
// ==========================================

class UserDatabase {
  UserDatabase._();

  static final UserDatabase instance = UserDatabase._();

  // Sử dụng chung một Future mở database.
  Future<Database>? _databaseFuture;

  Future<Database> get database {
    return _databaseFuture ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw StateError('DB_VERSION must be 1 or 2');
    }

    final directory = await getDatabasesPath();

    final dbPath = p.join(
      directory,
      'users_migration_demo.db',
    );

    return openDatabase(
      dbPath,
      version: schemaVersion,

      // Tạo database mới.
      onCreate: (db, version) async {
        if (version == 1) {
          // V1: Chưa có phone_number.
          await db.execute('''
            CREATE TABLE Users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              email TEXT
            )
          ''');
        } else {
          // V2: Có phone_number.
          await db.execute('''
            CREATE TABLE Users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              email TEXT,
              phone_number TEXT
            )
          ''');
        }
      },

      // Migration từ V1 lên V2.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2 && newVersion >= 2) {
          await db.execute('''
            ALTER TABLE Users
            ADD COLUMN phone_number TEXT
          ''');
        }
      },
    );
  }

  // ========================================
  // CÂU 12: QUERY -> MODEL
  // ========================================

  Future<List<User>> getUsers() async {
    final db = await database;

    // db.query trả về:
    // Future<List<Map<String, Object?>>>
    final rows = await db.query(
      'Users',
      orderBy: 'id DESC',
    );

    // Chuyển Map thành User Object.
    return rows
        .map((row) => User.fromMap(row))
        .toList();
  }

  // Thêm người dùng.
  Future<void> addUser(
      String name,
      String email,
      ) async {
    final db = await database;

    await db.insert('Users', {
      'name': name,
      'email': email,
    });
  }

  // Cập nhật số điện thoại ở Version 2.
  Future<void> setPhone(
      int id,
      String phone,
      ) async {
    if (schemaVersion < 2) return;

    final db = await database;

    await db.update(
      'Users',
      {'phone_number': phone},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// ==========================================
// 3. FLUTTER APPLICATION
// ==========================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SQLite User Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: const UsersPage(),
    );
  }
}

// ==========================================
// 4. USER LIST SCREEN
// ==========================================

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late Future<List<User>> usersFuture;

  int count = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Tạo Future để truy vấn database.
  void _loadData() {
    usersFuture = UserDatabase.instance.getUsers();
  }

  // Tải lại dữ liệu khi thêm hoặc cập nhật User.
  void _refresh() {
    setState(() {
      _loadData();
    });
  }

  // Thêm User mới.
  Future<void> _add() async {
    try {
      count++;

      final uniqueId =
          DateTime.now().microsecondsSinceEpoch;

      await UserDatabase.instance.addUser(
        'Người dùng $count',
        'user$uniqueId@example.com',
      );

      if (!mounted) return;
      _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  // Cập nhật phone_number ở Version 2.
  Future<void> _setPhone(User user) async {
    try {
      await UserDatabase.instance.setPhone(
        user.id,
        '0901234567',
      );

      if (!mounted) return;
      _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  // Thông báo lỗi.
  void _showError(Object e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lỗi: $e'),
      ),
    );
  }

  // ========================================
  // 5. GIAO DIỆN CHÍNH
  // ========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách người dùng'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại dữ liệu',
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Thêm User'),
      ),

      // FUTUREBUILDER - CÂU 12
      body: FutureBuilder<List<User>>(
        future: usersFuture,
        builder: (context, snapshot) {
          // Đang tải dữ liệu.
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Xử lý lỗi.
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi truy vấn: ${snapshot.error}',
              ),
            );
          }

          final users = snapshot.data ?? [];

          // Danh sách rỗng.
          if (users.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có người dùng.\n'
                    'Nhấn Thêm User để bắt đầu.',
                textAlign: TextAlign.center,
              ),
            );
          }

          // LISTVIEW.BUILDER - CÂU 12
          return ListView.builder(
            padding: const EdgeInsets.only(
              top: 12,
              bottom: 90,
            ),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),

                  title: Text(user.name),

                  // V1 chỉ có email.
                  // V2 có thêm số điện thoại.
                  subtitle: Text(
                    schemaVersion == 1
                        ? (user.email ?? '')
                        : '${user.email ?? ""}\n'
                        'SĐT: ${user.phoneNumber ?? "NULL"}',
                  ),

                  isThreeLine: schemaVersion >= 2,

                  // Chỉ hiển thị ở V2.
                  trailing: schemaVersion >= 2
                      ? IconButton(
                    tooltip: 'Cập nhật số điện thoại',
                    onPressed: () => _setPhone(user),
                    icon: const Icon(
                      Icons.phone,
                    ),
                  )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
