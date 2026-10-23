import 'dart:io';

import 'package:flutter/material.dart';

import '../models/demo_models.dart';
import '../widgets/demo_widgets.dart';

// CÂU 09 — MỞ FILE NÀY KHI TRÌNH BÀY.
// Thứ tự chỉ code: C9.1 -> C9.2 -> C9.3 -> chạy nút Bắt đầu đọc file.

Stream<ReadProgress> readFileProgress(
  File file, {
  Duration updateInterval = const Duration(milliseconds: 100),
}) async* {
  final clock = Stopwatch()..start();
  final total = await file.length();
  var received = 0;
  var lastUpdate = 0;

  // Gom cách tạo event vào một chỗ để phần vòng lặp dễ đọc.
  ReadProgress progress({bool done = false}) => ReadProgress(
    bytesRead: received,
    totalBytes: total,
    elapsedMicroseconds: clock.elapsedMicroseconds,
    isComplete: done,
  );

  if (total == 0) {
    yield progress(done: true);
    return;
  }
  yield progress();

  // C9.1 — CHỈ VÀO ĐÂY: đọc từng khối và cộng byte thực tế.
  // NÓI: "openRead phát từng chunk. Em cộng chunk.length để biết đã đọc bao nhiêu."
  await for (final chunk in file.openRead()) {
    received += chunk.length;

    // C9.2 — CHỈ VÀO if và yield: chỉ gửi cập nhật UI khoảng 100 ms/lần.
    // NÓI: "File vẫn đọc liên tục; em chỉ giới hạn số sự kiện tiến độ."
    if (clock.elapsedMicroseconds - lastUpdate >=
        updateInterval.inMicroseconds) {
      yield progress();
      lastUpdate = clock.elapsedMicroseconds;
    }
  }

  if (received != total) {
    throw FileSystemException(
      'File thay đổi trong lúc đọc, hãy chạy lại.',
      file.path,
    );
  }
  yield progress(done: true); // Luôn phát trạng thái cuối khi đọc thành công.
}

// Màn hình tạo _stream MỘT LẦN khi bấm nút và giữ trong State.
// CHỈ THÊM NẾU CẦN: tìm "C9.STATE" trong progress_demo_panel.dart.
class FileProgressBar extends StatelessWidget {
  const FileProgressBar({
    super.key,
    required this.stream,
    required this.reading,
  });
  final Stream<ReadProgress>? stream;
  final bool reading;

  @override
  Widget build(BuildContext context) {
    // C9.3 — CHỈ VÀO ĐÂY: stream cấp dữ liệu cho StreamBuilder.
    // NÓI: "StreamBuilder nhận tiến độ mới và dựng lại vùng UI này."
    return StreamBuilder<ReadProgress>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorMessage('Không đọc được file: ${snapshot.error}');
        }
        final progress = snapshot.data;
        if (progress == null) {
          return Column(
            children: [
              LinearProgressIndicator(value: reading ? null : 0),
              Text(reading ? 'Đang mở file…' : 'Chưa đọc file / đã dừng.'),
            ],
          );
        }

        // C9.4 — CHỈ VÀO value: fraction = bytesRead / totalBytes.
        // NÓI: "Ví dụ đọc 57 trên 100 MiB thì thanh tiến độ hiển thị 57%."
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: progress.fraction, minHeight: 10),
            const SizedBox(height: 12),
            Text(
              '${(progress.fraction * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              '${formatBytes(progress.bytesRead)} / ${formatBytes(progress.totalBytes)}',
            ),
            Text(
              'Thời gian đọc: ${formatDuration(progress.elapsedMicroseconds)}',
            ),
            if (snapshot.connectionState == ConnectionState.done &&
                progress.isComplete)
              const Text('Đã đọc xong toàn bộ byte.'),
          ],
        );
      },
    );
  }
}
