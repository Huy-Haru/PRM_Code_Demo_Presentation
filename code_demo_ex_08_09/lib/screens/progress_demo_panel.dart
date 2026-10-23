import 'dart:io';

import 'package:flutter/material.dart';

import '../models/demo_models.dart';
import '../demo/cau_09_stream.dart';
import '../widgets/demo_widgets.dart';

enum _FileChoice { json, ndjson, empty, missing }

class ProgressDemoPanel extends StatefulWidget {
  const ProgressDemoPanel({
    super.key,
    required this.files,
    required this.locked,
    required this.onRunningChanged,
    this.readProgress = readFileProgress,
  });
  final DemoFiles? files;
  final bool locked;
  final ValueChanged<bool> onRunningChanged;
  final Stream<ReadProgress> Function(File file) readProgress;

  @override
  State<ProgressDemoPanel> createState() => _ProgressDemoPanelState();
}

class _ProgressDemoPanelState extends State<ProgressDemoPanel> {
  _FileChoice _choice = _FileChoice.json;
  Stream<ReadProgress>? _stream;
  bool _reading = false;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant ProgressDemoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.files != widget.files) {
      ++_generation;
      _stream = null;
    }
  }

  void _start() {
    final files = widget.files!;
    final path = switch (_choice) {
      _FileChoice.json => files.jsonPath,
      _FileChoice.ndjson => files.ndjsonPath,
      _FileChoice.empty => files.emptyPath,
      _FileChoice.missing => files.missingPath,
    };
    final generation = ++_generation;
    setState(() {
      _reading = true;
      // C9.STATE — CHỈ VÀO ĐÂY nếu hỏi stream được tạo ở đâu.
      // NÓI: "Em tạo stream khi bấm nút và giữ trong State, không tạo trong build."
      _stream = _read(File(path), generation);
    });
    widget.onRunningChanged(true);
  }

  Stream<ReadProgress> _read(File file, int generation) async* {
    try {
      yield* widget.readProgress(file);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _reading = false);
        widget.onRunningChanged(false);
      }
    }
  }

  void _cancel() {
    ++_generation;
    setState(() {
      _stream = null; // StreamBuilder hủy subscription cũ, đóng luồng đọc.
      _reading = false;
    });
    widget.onRunningChanged(false);
  }

  @override
  void dispose() {
    ++_generation;
    // StreamBuilder sẽ tự hủy subscription khi bị tháo khỏi cây widget.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.files != null && !widget.locked;
    return DemoSection(
      title: 'Câu 09 · File.openRead() + StreamBuilder',
      children: [
        const FlowExplanation(
          steps: ['Chunk byte', 'Đếm byte đã đọc', 'Stream tiến độ', 'UI'],
        ),
        const SizedBox(height: 12),
        const Text(
          'Tiến độ = số byte đã đọc / tổng byte. Chỉ phát cập nhật trung gian '
          'mỗi khoảng 100 ms, luôn phát kết quả cuối khi đọc thành công.',
        ),
        const SizedBox(height: 16),
        DropdownButton<_FileChoice>(
          isExpanded: true,
          value: _choice,
          onChanged: widget.locked
              ? null
              : (value) => setState(() => _choice = value!),
          items: const [
            DropdownMenuItem(
              value: _FileChoice.json,
              child: Text('File JSON mảng'),
            ),
            DropdownMenuItem(
              value: _FileChoice.ndjson,
              child: Text('File NDJSON'),
            ),
            DropdownMenuItem(
              value: _FileChoice.empty,
              child: Text('File rỗng (0 byte)'),
            ),
            DropdownMenuItem(
              value: _FileChoice.missing,
              child: Text('File không tồn tại (thử lỗi)'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              key: const Key('read-file'),
              onPressed: ready ? _start : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Bắt đầu đọc file'),
            ),
            if (_reading)
              TextButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.stop),
                label: const Text('Dừng đọc'),
              ),
          ],
        ),
        const SizedBox(height: 20),
        // Key mới xóa snapshot cũ khi bắt đầu lại, kể cả sau lỗi hoặc đổi file.
        FileProgressBar(
          key: ValueKey(_generation),
          stream: _stream,
          reading: _reading,
        ),
        const Divider(height: 32),
        const Text(
          'Không gom các chunk vào RAM và không parse trong builder. '
          '100% ở màn hình này chỉ có nghĩa đọc xong byte. '
          'File trên máy nhanh có thể hoàn tất trước lần cập nhật 100 ms đầu tiên; '
          'demo không thêm độ trễ giả.',
        ),
        const CodeExample(
          code: '''// Tạo một lần khi người dùng bấm nút.
setState(() => _stream = readFileProgress(file));

// Chỉ lắng nghe và dựng vùng UI nhỏ.
StreamBuilder<ReadProgress>(
  stream: _stream,
  builder: (context, snap) {
    if (snap.hasError) return Text('Lỗi đọc file');
    return LinearProgressIndicator(value: snap.data?.fraction ?? 0);
  },
)
// Code đang chạy: lib/demo/cau_09_stream.dart, các mốc C9.1 đến C9.4.''',
        ),
      ],
    );
  }
}
