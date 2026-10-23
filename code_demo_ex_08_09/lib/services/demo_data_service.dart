import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/demo_models.dart';

// Hỗ trợ tạo dữ liệu và thống kê. Không cần mở phần này khi thuyết trình.
Future<DemoFiles> prepareDemoFiles(int records) =>
    compute(createDemoFiles, records, debugLabel: 'prepare-demo-files');

class StudentStatistics {
  int records = 0;
  int scoreTotal = 0;
  int completedActivities = 0;
  final List<String> sampleNames = [];

  void add(Map<String, dynamic> row) {
    final scores = row['scores'] as Map<String, dynamic>;
    scoreTotal += (scores['theory'] as int) + (scores['practice'] as int);
    final activities = row['activities'] as List<dynamic>;
    completedActivities += activities
        .where(
          (activity) => (activity as Map<String, dynamic>)['completed'] == true,
        )
        .length;
    if (sampleNames.length < 3) sampleNames.add(row['name'] as String);
    records++;
  }
}

Future<AnalysisResult> saveStatistics(
  StudentStatistics stats,
  String outputPath,
  Stopwatch watch,
) async {
  final result = AnalysisResult(
    records: stats.records,
    averageScore: stats.records == 0
        ? 0
        : stats.scoreTotal / (stats.records * 2),
    completedActivities: stats.completedActivities,
    sampleNames: List.unmodifiable(stats.sampleNames),
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
