import 'package:flutter/material.dart';

import '../models/demo_models.dart';
import '../services/file_demo_service.dart';
import '../widgets/demo_widgets.dart';
import 'isolate_demo_panel.dart';
import 'progress_demo_panel.dart';

class FileDemoHome extends StatefulWidget {
  const FileDemoHome({super.key});

  @override
  State<FileDemoHome> createState() => _FileDemoHomeState();
}

class _FileDemoHomeState extends State<FileDemoHome> {
  DemoFiles? _files;
  int _rows = 50000;
  int _tab = 0;
  int _taps = 0;
  bool _preparing = false;
  bool _running = false;
  String? _error;

  Future<void> _prepare() async {
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      // Tạo dữ liệu cũng ở worker, không làm khựng UI trước khi demo.
      final files = await prepareDemoFiles(_rows);
      if (mounted) setState(() => _files = files);
    } catch (error) {
      if (mounted) setState(() => _error = 'Không tạo được dữ liệu: $error');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _preparing || _running;
    final files = _files;
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Lab • Module 9'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Câu 08–09  ·  Nguyễn Hải Huy  ·  HE190724'),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DemoSection(
                      title: '1. Chuẩn bị file mẫu',
                      children: [
                        const Text(
                          'Hai file chứa cùng dữ liệu sinh viên lồng nhau: '
                          'JSON mảng cho compute, NDJSON cho worker stream.',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            DropdownButton<int>(
                              isExpanded: true,
                              value: _rows,
                              onChanged: locked
                                  ? null
                                  : (value) => setState(() => _rows = value!),
                              items: const [
                                DropdownMenuItem(
                                  value: 10000,
                                  child: Text('10.000 bản ghi'),
                                ),
                                DropdownMenuItem(
                                  value: 50000,
                                  child: Text('50.000 bản ghi'),
                                ),
                                DropdownMenuItem(
                                  value: 100000,
                                  child: Text('100.000 bản ghi'),
                                ),
                              ],
                            ),
                            FilledButton.icon(
                              key: const Key('prepare-data'),
                              onPressed: locked ? null : _prepare,
                              icon: const Icon(
                                Icons.create_new_folder_outlined,
                              ),
                              label: Text(
                                _preparing
                                    ? 'Đang tạo file…'
                                    : 'Tạo dữ liệu mẫu',
                              ),
                            ),
                          ],
                        ),
                        if (_preparing) ...[
                          const SizedBox(height: 12),
                          const LinearProgressIndicator(),
                        ],
                        if (_error != null) ErrorMessage(_error!),
                        if (files != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Sẵn sàng: ${files.recordCount} bản ghi\n'
                            'JSON: ${formatBytes(files.jsonBytes)}  ·  '
                            'NDJSON: ${formatBytes(files.ndjsonBytes)}',
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Thư mục file demo'),
                            children: [SelectableText(files.directory)],
                          ),
                        ],
                        const Text(
                          'File tự tạo trong bộ nhớ tạm của app. '
                          'Chọn 10.000 bản ghi nếu thiết bị ít RAM.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    DemoSection(
                      title: 'Thử độ phản hồi của UI',
                      children: [
                        Row(
                          children: [
                            if (locked) ...[
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(width: 16),
                            ] else ...[
                              const Icon(Icons.touch_app_outlined),
                              const SizedBox(width: 16),
                            ],
                            Expanded(
                              child: Text(
                                locked
                                    ? 'Đang làm việc. Bạn vẫn có thể chạm nút '
                                          'và cuộn màn hình.'
                                    : 'Chạm nút này khi file đang được xử lý.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('ui-counter'),
                          onPressed: () => setState(() => _taps++),
                          icon: const Icon(Icons.add),
                          label: Text('UI đã nhận $_taps lần chạm'),
                        ),
                      ],
                    ),
                    // IndexedStack giữ State/stream khi chuyển giữa hai câu.
                    IndexedStack(
                      index: _tab,
                      children: [
                        IsolateDemoPanel(
                          files: files,
                          locked: locked,
                          onRunningChanged: (value) =>
                              setState(() => _running = value),
                        ),
                        ProgressDemoPanel(
                          files: files,
                          locked: locked,
                          onRunningChanged: (value) =>
                              setState(() => _running = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.memory_outlined),
            selectedIcon: Icon(Icons.memory),
            label: 'Câu 08 · Isolate',
          ),
          NavigationDestination(
            icon: Icon(Icons.downloading_outlined),
            selectedIcon: Icon(Icons.downloading),
            label: 'Câu 09 · Tiến độ',
          ),
        ],
      ),
    );
  }
}
