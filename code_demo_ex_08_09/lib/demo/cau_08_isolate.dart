import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../models/demo_models.dart';
import '../services/demo_data_service.dart';
import '../services/isolate_worker_support.dart';

// CÂU 08 — MỞ FILE NÀY KHI TRÌNH BÀY.
// Thứ tự chỉ code: C8.1 -> C8.2 -> chạy nút compute trên app.
// Sau đó giới thiệu thêm C8.3 -> C8.4 -> chạy nút Isolate.spawn.

// C8.1 — CHỈ VÀO ĐÂY: compute gọi callback top-level ở isolate phụ trên native.
// NÓI: "Main gửi đường dẫn; worker xử lý rồi trả một kết quả nhỏ về UI."
Future<AnalysisResult> analyzeWithCompute(AnalysisRequest request) {
  return compute(analyzeJsonFile, request);
}

Future<AnalysisResult> analyzeJsonFile(AnalysisRequest request) async {
  final watch = Stopwatch()..start();

  // C8.2 — CHỈ VÀO 3 BƯỚC: ĐỌC -> PARSE -> XỬ LÝ VÀ GHI.
  // NÓI: "Đọc file và jsonDecode đều nằm trong callback chạy ở worker."
  final text = await File(request.inputPath).readAsString();
  final rows = jsonDecode(text) as List<dynamic>;
  final stats = StudentStatistics();
  for (final row in rows) {
    stats.add(row as Map<String, dynamic>);
  }
  return saveStatistics(stats, request.outputPath, watch);
  // LƯU Ý KHI NÓI: cách này vẫn nạp toàn bộ JSON vào RAM.
}

// C8.3 — CHỈ VÀO ĐÂY: tự tạo worker, truyền request và SendPort.
// NÓI: "Isolate.spawn cho phép worker gửi tiến độ, kết quả hoặc lỗi về Main."
Stream<AnalysisEvent> analyzeWithIsolate(AnalysisRequest request) {
  return workerMessages(
    (replyTo, exitTo) => Isolate.spawn(
      runWorkerJob,
      WorkerJob(request, replyTo, readNdjsonInWorker),
      onError: replyTo,
      onExit: exitTo,
    ),
  );
  // workerMessages quản lý ReceivePort và hủy worker; không cần đọc phần đó.
}

Future<AnalysisResult?> readNdjsonInWorker(
  AnalysisRequest request,
  SendPort mainPort,
  CancellationSignal cancellation,
) async {
  final watch = Stopwatch()..start();
  final updateClock = Stopwatch()..start();
  final file = File(request.inputPath);
  final total = await file.length();
  var bytesRead = 0;
  final stats = StudentStatistics();
  mainPort.send(AnalysisProgress(0, total, 0));

  // C8.4 — CHỈ VÀO ĐÂY: đọc stream, tách đúng dòng rồi parse từng bản ghi.
  // NÓI: "NDJSON có một JSON hoàn chỉnh trên mỗi dòng; không parse từng chunk."
  final lines = file
      .openRead()
      .map((chunk) {
        bytesRead += chunk.length;
        return chunk;
      })
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (final line in lines) {
    if (cancellation.isCancelled) return null;
    if (line.trim().isEmpty) continue;
    stats.add(jsonDecode(line) as Map<String, dynamic>);

    // C8.5 — CHỈ VÀO send: gửi tiến độ về Main, khoảng 100 ms/lần.
    if (updateClock.elapsedMilliseconds >= 100) {
      mainPort.send(AnalysisProgress(bytesRead, total, stats.records));
      updateClock.reset();
    }
  }

  // NÓI: "Worker ghi summary xong mới báo hoàn tất."
  if (cancellation.isCancelled) return null;
  return saveStatistics(stats, request.outputPath, watch);
}
