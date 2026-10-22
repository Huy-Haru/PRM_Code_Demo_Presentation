import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../models/demo_models.dart';

Future<DemoFiles> prepareDemoFiles(int records) =>
    compute(createDemoFiles, records, debugLabel: 'prepare-demo-files');

// CÂU 08: compute chạy cả đọc file, parse và ghi kết quả ở worker trên native.
Future<AnalysisResult> analyzeWithCompute(AnalysisRequest request) =>
    compute(analyzeJsonFile, request, debugLabel: 'read-parse-write-json');

// Callback top-level giúp tránh closure vô tình giữ state của UI.
Future<AnalysisResult> analyzeJsonFile(AnalysisRequest request) async {
  final watch = Stopwatch()..start();
  final raw = await File(request.inputPath).readAsString();
  final rows = jsonDecode(raw) as List<dynamic>;
  final stats = _Statistics();
  for (final row in rows) {
    stats.add(row as Map<String, dynamic>);
  }
  return _saveResult(stats, request.outputPath, watch);
}

class _WorkerRequest {
  const _WorkerRequest(this.request, this.replyTo);
  final AnalysisRequest request;
  final SendPort replyTo;
}

class _WorkerFailure {
  const _WorkerFailure(this.message, this.stack);
  final String message;
  final String stack;
}

class _WorkerReady {
  const _WorkerReady(this.commands);
  final SendPort commands;
}

class _WorkerExited {
  const _WorkerExited();
}

// CÂU 08: worker NDJSON đọc stream, parse từng dòng rồi ghi summary.
// NDJSON yêu cầu MỖI DÒNG là một JSON hoàn chỉnh, khác JSON mảng nhiều dòng.
void _ndjsonWorker(_WorkerRequest job) async {
  final commands = ReceivePort();
  var cancelled = false;
  final commandSubscription = commands.listen((message) {
    if (message == 'cancel') cancelled = true;
  });
  job.replyTo.send(_WorkerReady(commands.sendPort));
  try {
    final watch = Stopwatch()..start();
    final throttle = Stopwatch()..start();
    final file = File(job.request.inputPath);
    final total = await file.length();
    var received = 0;
    final stats = _Statistics();
    job.replyTo.send(AnalysisProgress(0, total, 0));

    final lines = file
        .openRead()
        .map((chunk) {
          received += chunk.length;
          return chunk;
        })
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      // Hủy nhẹ nhàng: break sẽ await đóng subscription và file đang đọc.
      if (cancelled) return;
      if (line.trim().isEmpty) continue;
      stats.add(jsonDecode(line) as Map<String, dynamic>);
      if (throttle.elapsedMilliseconds >= 100) {
        job.replyTo.send(AnalysisProgress(received, total, stats.records));
        throttle.reset();
      }
    }

    if (cancelled) return;
    final result = await _saveResult(stats, job.request.outputPath, watch);
    // Hoàn tất chỉ sau khi đã parse VÀ ghi summary thành công.
    job.replyTo.send(AnalysisCompleted(result));
  } catch (error, stack) {
    job.replyTo.send(_WorkerFailure(error.toString(), stack.toString()));
  } finally {
    await commandSubscription.cancel();
    commands.close();
  }
}

Stream<AnalysisEvent> analyzeWithIsolate(AnalysisRequest request) async* {
  final inbox = ReceivePort();
  final exits = ReceivePort();
  final exited = Completer<void>();
  final exitSubscription = exits.listen((_) {
    if (!exited.isCompleted) exited.complete();
    inbox.sendPort.send(const _WorkerExited());
  });
  Isolate? worker;
  SendPort? commands;
  try {
    worker = await Isolate.spawn(
      _ndjsonWorker,
      _WorkerRequest(request, inbox.sendPort),
      // Exit có cổng riêng để hủy có thể đợi worker đóng file xong.
      onError: inbox.sendPort,
      onExit: exits.sendPort,
      errorsAreFatal: true,
      debugName: 'stream-ndjson-worker',
    );
    await for (final message in inbox) {
      if (message is _WorkerReady) {
        commands = message.commands;
        continue;
      }
      if (message is AnalysisCompleted) {
        yield message;
        return;
      }
      if (message is AnalysisProgress) {
        yield message;
      } else if (message is _WorkerFailure) {
        Error.throwWithStackTrace(
          StateError(message.message),
          StackTrace.fromString(message.stack),
        );
      } else if (message is List && message.length == 2) {
        Error.throwWithStackTrace(
          StateError(message[0].toString()),
          StackTrace.fromString(message[1].toString()),
        );
      } else if (message is _WorkerExited) {
        throw StateError('Worker thoát trước khi gửi kết quả.');
      }
    }
  } finally {
    // Hủy nhẹ nhàng trước, chờ exit để file đã thực sự được đóng.
    if (worker != null && !exited.isCompleted) {
      if (commands == null) {
        worker.kill(priority: Isolate.immediate);
      } else {
        commands.send('cancel');
      }
      try {
        await exited.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        worker.kill(priority: Isolate.immediate);
        await exited.future.timeout(const Duration(seconds: 2));
      }
    }
    inbox.close();
    await exitSubscription.cancel();
    exits.close();
  }
}

// CÂU 09: chỉ đếm byte nhẹ trên Main Isolate. Không parse JSON trong vòng lặp.
Stream<ReadProgress> readFileProgress(
  File file, {
  Duration updateInterval = const Duration(milliseconds: 100),
}) async* {
  final watch = Stopwatch()..start();
  final total = await file.length();
  var received = 0;
  var lastUpdate = 0;
  if (total == 0) {
    yield ReadProgress(
      bytesRead: 0,
      totalBytes: 0,
      elapsedMicroseconds: watch.elapsedMicroseconds,
      isComplete: true,
    );
    return;
  }
  yield ReadProgress(bytesRead: 0, totalBytes: total, elapsedMicroseconds: 0);
  await for (final chunk in file.openRead()) {
    received += chunk.length;
    // Giới hạn nhịp phát event UI, KHÔNG làm chậm tốc độ đọc bằng delay.
    if (watch.elapsedMicroseconds - lastUpdate >=
        updateInterval.inMicroseconds) {
      yield ReadProgress(
        bytesRead: received,
        totalBytes: total,
        elapsedMicroseconds: watch.elapsedMicroseconds,
      );
      lastUpdate = watch.elapsedMicroseconds;
    }
  }
  if (received != total) {
    throw FileSystemException(
      'Kích thước file thay đổi trong lúc đọc. Hãy tạo lại dữ liệu.',
      file.path,
    );
  }
  yield ReadProgress(
    bytesRead: received,
    totalBytes: total,
    elapsedMicroseconds: watch.elapsedMicroseconds,
    isComplete: true,
  );
}

class _Statistics {
  int records = 0;
  int _scoreTotal = 0;
  int completedActivities = 0;
  final List<String> _samples = [];

  void add(Map<String, dynamic> row) {
    final scores = row['scores'] as Map<String, dynamic>;
    _scoreTotal += (scores['theory'] as int) + (scores['practice'] as int);
    final activities = row['activities'] as List<dynamic>;
    completedActivities += activities
        .where(
          (activity) => (activity as Map<String, dynamic>)['completed'] == true,
        )
        .length;
    if (_samples.length < 3) _samples.add(row['name'] as String);
    records++;
  }
}

Future<AnalysisResult> _saveResult(
  _Statistics stats,
  String outputPath,
  Stopwatch watch,
) async {
  final result = AnalysisResult(
    records: stats.records,
    averageScore: stats.records == 0
        ? 0
        : stats._scoreTotal / (stats.records * 2),
    completedActivities: stats.completedActivities,
    sampleNames: List.unmodifiable(stats._samples),
    elapsedMicroseconds: 0,
    outputPath: outputPath,
  );
  await File(outputPath)
      .writeAsString(jsonEncode(result.toJson()), flush: true);
  return AnalysisResult(
    records: result.records,
    averageScore: result.averageScore,
    completedActivities: result.completedActivities,
    sampleNames: result.sampleNames,
    elapsedMicroseconds: watch.elapsedMicroseconds,
    outputPath: outputPath,
  );
}

Future<DemoFiles> createDemoFiles(int records) async {
  if (records < 0 || records > 100000) {
    throw ArgumentError.value(records, 'records', 'Chọn từ 0 đến 100000.');
  }
  // File nằm trong cache tạm của ứng dụng, không ghi vào thư mục người dùng.
  final directory = await Directory.systemTemp.createTemp('flutter_file_lab_');
  final jsonFile = File('${directory.path}/students.json');
  final ndjsonFile = File('${directory.path}/students.ndjson');
  final emptyFile = File('${directory.path}/empty.json');
  await _writeRecords(jsonFile, records, ndjson: false);
  await _writeRecords(ndjsonFile, records, ndjson: true);
  await emptyFile.writeAsString('');
  return DemoFiles(
    directory: directory.path,
    jsonPath: jsonFile.path,
    ndjsonPath: ndjsonFile.path,
    emptyPath: emptyFile.path,
    recordCount: records,
    jsonBytes: await jsonFile.length(),
    ndjsonBytes: await ndjsonFile.length(),
  );
}

Future<void> _writeRecords(File file, int count, {required bool ndjson}) async {
  final sink = file.openWrite();
  try {
    // addStream nhận từng khối và chờ consumer, tránh gom cả file vào RAM.
    await sink.addStream(_encodedRecords(count, ndjson: ndjson));
    await sink.flush();
  } finally {
    await sink.close();
  }
}

Stream<List<int>> _encodedRecords(int count, {required bool ndjson}) async* {
  var buffer = StringBuffer(ndjson ? '' : '[');
  for (var i = 0; i < count; i++) {
    if (!ndjson && i > 0) buffer.write(',');
    buffer.write(
      jsonEncode({
        'id': i + 1,
        'name': 'Sinh viên ${i + 1}',
        'profile': {
          'email': 'student${i + 1}@example.com',
          'city': 'Hà Nội',
          'skills': ['Dart', 'Flutter', 'SQLite'],
        },
        'scores': {'theory': i % 101, 'practice': (i * 7) % 101},
        'activities': [
          for (var m = 1; m <= 3; m++)
            {'module': m, 'completed': (i + m).isEven},
        ],
      }),
    );
    if (ndjson) buffer.writeln();
    if ((i + 1) % 128 == 0) {
      yield utf8.encode(buffer.toString());
      buffer = StringBuffer();
    }
  }
  if (!ndjson) buffer.write(']');
  if (buffer.isNotEmpty) yield utf8.encode(buffer.toString());
}
