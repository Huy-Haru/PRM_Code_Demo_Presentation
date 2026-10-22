import 'dart:io';

import 'package:flutter/material.dart';

import 'data/todo.dart';
import 'data/todo_database.dart';

const _rowCount = 1000;

class _RunResult {
  const _RunResult(this.label, this.elapsed);

  final String label;
  final Duration elapsed;
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final _db = TodoDatabase.instance;
  final List<_RunResult> _results = [];

  bool _busy = false;
  int _count = 0;
  String? _error;
  String? _fileReport;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() => _guard(() async {
        final count = await _db.count();
        if (mounted) setState(() => _count = count);
      });

  /// Chạy một thao tác, bật/tắt trạng thái busy và gom lỗi để hiển thị trên UI.
  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runInsert(
    String label,
    Future<void> Function(List<Todo>) insert,
  ) =>
      _guard(() async {
        // Xóa trước để hai lần đo cùng điều kiện.
        await _db.clear();
        final todos =
            List.generate(_rowCount, (i) => Todo(title: 'Todo #${i + 1}'));

        final watch = Stopwatch()..start();
        await insert(todos);
        watch.stop();

        final count = await _db.count();
        if (!mounted) return;
        setState(() {
          _count = count;
          _results.insert(0, _RunResult(label, watch.elapsed));
        });
      });

  Future<void> _clear() => _guard(() async {
        await _db.clear();
        if (mounted) setState(() => _count = 0);
      });

  Future<void> _inspectFile() => _guard(() async {
        final path = await _db.filePath();
        final file = File(path);
        final header = <int>[];
        await for (final chunk in file.openRead(0, 16)) {
          header.addAll(chunk);
        }
        final text = String.fromCharCodes(header).replaceAll('\u0000', '');
        final plaintext = text.startsWith('SQLite format 3');
        if (!mounted) return;
        setState(() {
          _fileReport = 'File: $path\n'
              '16 byte đầu: "$text"\n'
              '${plaintext ? 'Đọc được header SQLite => file CHƯA mã hóa.' : 'Không thấy header SQLite => có thể đã mã hóa.'}';
        });
      });

  String _format(Duration d) => '${d.inMilliseconds} ms';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('SQLite: Batch & bảo mật')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                title: const Text('Số dòng trong bảng todos'),
                trailing: Text('$_count', style: theme.textTheme.headlineSmall),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _runInsert(
                      'Từng dòng (await insert)', _db.insertOneByOne),
              icon: const Icon(Icons.hourglass_bottom),
              label: const Text('Insert 1000 dòng từng lệnh'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _runInsert('Batch (commit 1 lần)', _db.insertBatch),
              icon: const Icon(Icons.bolt),
              label: const Text('Insert 1000 dòng bằng Batch'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _clear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Xóa hết'),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Text('Kết quả đo', style: theme.textTheme.titleMedium),
            if (_results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Chưa có lần chạy nào.'),
              )
            else
              ..._results.map(
                (r) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.label),
                  trailing: Text(_format(r.elapsed)),
                ),
              ),
            const Divider(height: 32),
            Text('Bảo mật', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _inspectFile,
              icon: const Icon(Icons.lock_open),
              label: const Text('Kiểm tra file DB có mã hóa không'),
            ),
            if (_fileReport != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SelectableText(_fileReport!),
              ),
          ],
        ),
      ),
    );
  }
}
