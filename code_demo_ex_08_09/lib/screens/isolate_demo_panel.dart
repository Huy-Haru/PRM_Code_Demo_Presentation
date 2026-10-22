import 'dart:async';

import 'package:flutter/material.dart';

import '../models/demo_models.dart';
import '../services/file_demo_service.dart';
import '../widgets/demo_widgets.dart';

class IsolateDemoPanel extends StatefulWidget {
  const IsolateDemoPanel({
    super.key,
    required this.files,
    required this.locked,
    required this.onRunningChanged,
  });
  final DemoFiles? files;
  final bool locked;
  final ValueChanged<bool> onRunningChanged;

  @override
  State<IsolateDemoPanel> createState() => _IsolateDemoPanelState();
}

class _IsolateDemoPanelState extends State<IsolateDemoPanel> {
  StreamSubscription<AnalysisEvent>? _subscription;
  AnalysisResult? _result;
  AnalysisProgress? _progress;
  String? _error;
  String _method = 'compute()';
  bool _running = false;
  bool _canCancel = false;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant IsolateDemoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.files != widget.files) {
      _result = null;
      _error = null;
      _progress = null;
    }
  }

  void _begin(String method, {required bool canCancel}) {
    setState(() {
      _method = method;
      _running = true;
      _canCancel = canCancel;
      _result = null;
      _progress = null;
      _error = null;
    });
    widget.onRunningChanged(true);
  }

  void _finish() {
    if (!mounted) return;
    setState(() {
      _running = false;
      _canCancel = false;
    });
    widget.onRunningChanged(false);
  }

  Future<void> _runCompute() async {
    final files = widget.files!;
    _begin('compute()', canCancel: false);
    try {
      final result = await analyzeWithCompute(
        AnalysisRequest(
          inputPath: files.jsonPath,
          outputPath: files.computeOutput,
        ),
      );
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = 'Xử lý thất bại: $error');
    } finally {
      _finish();
    }
  }

  void _runSpawn() {
    final files = widget.files!;
    final generation = ++_generation;
    _begin('Isolate.spawn()', canCancel: true);
    _subscription =
        analyzeWithIsolate(
          AnalysisRequest(
            inputPath: files.ndjsonPath,
            outputPath: files.isolateOutput,
          ),
        ).listen(
          (event) {
            if (!mounted || generation != _generation) return;
            setState(() {
              if (event is AnalysisProgress) _progress = event;
              if (event is AnalysisCompleted) _result = event.result;
            });
          },
          onError: (Object error) {
            if (!mounted || generation != _generation) return;
            setState(() => _error = 'Xử lý thất bại: $error');
          },
          onDone: () {
            if (generation == _generation) _finish();
          },
        );
  }

  Future<void> _cancel() async {
    ++_generation;
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() => _error = 'Đã hủy worker. Có thể chạy lại demo.');
    _finish();
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.files != null && !widget.locked;
    final result = _result;
    final progress = _progress;
    return DemoSection(
      title: 'Câu 08 · Xử lý file ngoài UI isolate',
      children: [
        const FlowExplanation(
          steps: [
            'Main gửi path',
            'Worker đọc / parse / ghi',
            'Main nhận kết quả',
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'compute xử lý JSON mảng và trả một kết quả. '
          'Isolate.spawn đọc NDJSON từng dòng, gửi tiến độ qua SendPort. '
          'Cả hai cùng tính thống kê và ghi một file summary.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              key: const Key('run-compute'),
              onPressed: ready ? _runCompute : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Chạy compute()'),
            ),
            OutlinedButton.icon(
              key: const Key('run-spawn'),
              onPressed: ready ? _runSpawn : null,
              icon: const Icon(Icons.hub_outlined),
              label: const Text('Chạy Isolate.spawn()'),
            ),
            if (_running && _canCancel)
              TextButton.icon(
                onPressed: _cancel,
                icon: const Icon(Icons.stop),
                label: const Text('Hủy worker'),
              ),
          ],
        ),
        if (widget.files == null)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Tạo dữ liệu mẫu trước khi chạy.'),
          ),
        if (_running) ...[
          const SizedBox(height: 20),
          LinearProgressIndicator(value: progress?.fraction),
          const SizedBox(height: 8),
          Text(
            progress == null
                ? '$_method đang đọc, parse và ghi summary…'
                : 'Đã nhận ${formatBytes(progress.bytesRead)} / '
                      '${formatBytes(progress.totalBytes)}; '
                      'đã xử lý ${progress.records} bản ghi.\n'
                      'Đọc đủ byte vẫn cần chờ parse và ghi kết quả.',
          ),
        ],
        if (_error != null) ErrorMessage(_error!),
        if (result != null) ...[
          const Divider(height: 32),
          Text(
            '$_method đã hoàn tất',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${result.records} bản ghi  ·  '
            'Điểm trung bình: ${result.averageScore.toStringAsFixed(2)}\n'
            '${result.completedActivities} hoạt động hoàn thành\n'
            'Đọc + parse + ghi tại worker: '
            '${formatDuration(result.elapsedMicroseconds)}\n'
            'Mẫu: ${result.sampleNames.join(', ')}',
          ),
          const SizedBox(height: 8),
          SelectableText('File kết quả: ${result.outputPath}'),
        ],
        const Divider(height: 32),
        const Text(
          'async giúp không chặn khi chờ I/O. jsonDecode vẫn tốn CPU ở '
          'isolate gọi nó. Ví dụ compute vẫn nạp toàn bộ JSON vào RAM; '
          'worker NDJSON chỉ giữ từng dòng và thống kê nhỏ.',
        ),
        const CodeExample(
          code: '''// Hàm top-level chạy ở worker trên native.
Future<AnalysisResult> analyzeJsonFile(AnalysisRequest request) async {
  final raw = await File(request.inputPath).readAsString();
  final rows = jsonDecode(raw) as List;
  // Tính thống kê và await ghi summary ngay tại worker.
}
final result = await compute(analyzeJsonFile, request);

// Worker stream: xem _ndjsonWorker() trong service.
final inbox = ReceivePort();
final worker = await Isolate.spawn(workerMain, inbox.sendPort);
// Nhận progress / kết quả / lỗi; đóng port và worker khi xong.''',
        ),
      ],
    );
  }
}
