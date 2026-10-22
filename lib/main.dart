import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

//
import 'object_save.dart'; // chứa AuthStorageService
import 'secure_save.dart'; // chứa User, saveUser(), getUser()

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Storage Tester',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Storage'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.lock), text: 'Secure Storage'),
              Tab(icon: Icon(Icons.person), text: 'SharedPreferences'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SecureStorageTab(),
            UserPrefsTab(),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TAB 1: TEST AuthStorageService
// ============================================================
class SecureStorageTab extends StatefulWidget {
  const SecureStorageTab({super.key});

  @override
  State<SecureStorageTab> createState() => _SecureStorageTabState();
}

class _SecureStorageTabState extends State<SecureStorageTab>
    with AutomaticKeepAliveClientMixin {
  final _service = AuthStorageService();
  final _tokenController = TextEditingController(text: 'my_access_token_123');

  String? _storedToken;
  bool? _hasToken;
  final List<String> _logs = [];
  bool _loading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  void _log(String msg) {
    final t = TimeOfDay.now();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => _logs.insert(0, '[$time] $msg'));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
    } catch (e) {
      _log('❌ Lỗi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Tự động đọc lại trạng thái hiện tại để hiển thị lên màn hình
  Future<void> _refresh() async {
    final token = await _service.getAccessToken();
    final has = await _service.hasAccessToken();
    if (!mounted) return;
    setState(() {
      _storedToken = token;
      _hasToken = has;
    });
  }

  Future<void> _saveToken() => _run(() async {
    final text = _tokenController.text.trim();
    if (text.isEmpty) {
      _log('⚠️ Token đang trống, hãy nhập token trước');
      return;
    }
    await _service.saveTokens(accessToken: text);
    _log('✅ saveTokens("$text")');
    await _refresh();
  });

  Future<void> _getToken() => _run(() async {
    final token = await _service.getAccessToken();
    _log('📖 getAccessToken() → ${token ?? "null"}');
    await _refresh();
  });

  Future<void> _hasTokenCheck() => _run(() async {
    final has = await _service.hasAccessToken();
    _log('🔎 hasAccessToken() → $has');
    await _refresh();
  });

  Future<void> _clearAuth() => _run(() async {
    await _service.clearAuthData();
    _log('🚪 clearAuthData() (Logout)');
    await _refresh();
  });

  Future<void> _clearAll() => _run(() async {
    await _service.clearAll();
    _log('🧹 clearAll() (Reset app)');
    await _refresh();
  });

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Nhập token ---
        TextField(
          controller: _tokenController,
          decoration: const InputDecoration(
            labelText: 'Access Token',
            prefixIcon: Icon(Icons.vpn_key),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        // --- Các nút thao tác ---
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : _saveToken,
              icon: const Icon(Icons.save),
              label: const Text('Lưu token'),
            ),
            FilledButton.tonalIcon(
              onPressed: _loading ? null : _getToken,
              icon: const Icon(Icons.download),
              label: const Text('Đọc token'),
            ),
            FilledButton.tonalIcon(
              onPressed: _loading ? null : _hasTokenCheck,
              icon: const Icon(Icons.verified_user),
              label: const Text('Kiểm tra đăng nhập'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _clearAuth,
              icon: const Icon(Icons.logout),
              label: const Text('Xóa token (Logout)'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _clearAll,
              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Xóa tất cả'),
            ),
          ],
        ),
        if (_loading) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 16),

        // --- Hiển thị dữ liệu hiện tại ---
        Card(
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dữ liệu hiện tại trong Secure Storage',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                _InfoRow(
                  label: 'Access Token',
                  value: _storedToken ?? '(chưa có / null)',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(
                      width: 110,
                      child: Text('Đã đăng nhập?'),
                    ),
                    Chip(
                      avatar: Icon(
                        _hasToken == true ? Icons.check_circle : Icons.cancel,
                        color: _hasToken == true ? Colors.green : cs.error,
                        size: 18,
                      ),
                      label: Text(_hasToken == null
                          ? '...'
                          : (_hasToken! ? 'Có' : 'Không')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- Log ---
        _LogCard(logs: _logs, onClear: () => setState(_logs.clear)),
      ],
    );
  }
}

// ============================================================
// TAB 2: TEST User + SharedPreferences
// ============================================================
class UserPrefsTab extends StatefulWidget {
  const UserPrefsTab({super.key});

  @override
  State<UserPrefsTab> createState() => _UserPrefsTabState();
}

class _UserPrefsTabState extends State<UserPrefsTab>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Nguyễn Văn A');
  final _ageController = TextEditingController(text: '25');
  final _emailController = TextEditingController(text: 'a@example.com');

  User? _storedUser;
  String? _rawJson;
  final List<String> _logs = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUser(silent: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _log(String msg) {
    final t = TimeOfDay.now();
    final time =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => _logs.insert(0, '[$time] $msg'));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final user = User(
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text.trim()),
        email: _emailController.text.trim(),
      );
      await saveUser(user);
      _log('✅ saveUser() → ${user.toJson()}');
      await _loadUser(silent: true);
    } catch (e) {
      _log('❌ Lỗi khi lưu: $e');
    }
  }

  /// [silent] = true: chỉ cập nhật màn hình, không ghi log (dùng sau khi lưu/xóa)
  Future<void> _loadUser({bool silent = false}) async {
    try {
      final user = await getUser();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_data');
      if (!mounted) return;
      setState(() {
        _storedUser = user;
        _rawJson = raw;
      });
      if (!silent) {
        _log(user == null
            ? '📖 getUser() → null (chưa có dữ liệu)'
            : '📖 getUser() → ${user.name}, ${user.age}, ${user.email}');
      }
    } catch (e) {
      _log('❌ Lỗi khi đọc: $e');
    }
  }

  /// Đổ dữ liệu đã lưu ngược lại vào form
  void _fillFormFromStored() {
    final u = _storedUser;
    if (u == null) {
      _log('⚠️ Chưa có user nào để điền vào form');
      return;
    }
    _nameController.text = u.name;
    _ageController.text = u.age.toString();
    _emailController.text = u.email;
    _log('📝 Đã điền dữ liệu đã lưu vào form');
  }

  Future<void> _delete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    _log('🗑️ Đã xóa key "user_data"');
    await _loadUser(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Form nhập user ---
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên',
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nhập tên' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tuổi',
                  prefixIcon: Icon(Icons.cake),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n < 0) return 'Tuổi phải là số nguyên ≥ 0';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty || !s.contains('@')) return 'Email không hợp lệ';
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- Nút thao tác ---
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Lưu User'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _loadUser(),
              icon: const Icon(Icons.download),
              label: const Text('Lấy User'),
            ),
            FilledButton.tonalIcon(
              onPressed: _fillFormFromStored,
              icon: const Icon(Icons.edit_note),
              label: const Text('Điền vào form'),
            ),
            OutlinedButton.icon(
              onPressed: _delete,
              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
              icon: const Icon(Icons.delete),
              label: const Text('Xóa User'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- Hiển thị dữ liệu đã lưu ---
        Card(
          color: cs.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('User đang lưu trong SharedPreferences',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(),
                if (_storedUser == null)
                  const Text('(chưa có dữ liệu)')
                else ...[
                  _InfoRow(label: 'Tên', value: _storedUser!.name),
                  _InfoRow(label: 'Tuổi', value: '${_storedUser!.age}'),
                  _InfoRow(label: 'Email', value: _storedUser!.email),
                ],
                const SizedBox(height: 12),
                const Text('JSON gốc:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _rawJson ?? 'null',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        _LogCard(logs: _logs, onClear: () => setState(_logs.clear)),
      ],
    );
  }
}

// ============================================================
// WIDGET DÙNG CHUNG
// ============================================================
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final List<String> logs;
  final VoidCallback onClear;

  const _LogCard({required this.logs, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Nhật ký thao tác',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                TextButton(onPressed: onClear, child: const Text('Xóa log')),
              ],
            ),
            const Divider(),
            if (logs.isEmpty)
              const Text('Chưa có thao tác nào.')
            else
              ...logs.map(
                    (l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l),
                ),
              ),
          ],
        ),
      ),
    );
  }
}