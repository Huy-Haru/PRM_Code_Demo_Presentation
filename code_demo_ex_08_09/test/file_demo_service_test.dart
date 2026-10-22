import 'dart:convert';
import 'dart:io';

import 'package:code_demo_ex_08_09/models/demo_models.dart';
import 'package:code_demo_ex_08_09/services/file_demo_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoFiles files;

  setUp(() async => files = await createDemoFiles(6));
  tearDown(() async {
    // Chỉ xóa thư mục cache riêng vừa được test tạo, không nhận path bên ngoài.
    final owned = Directory(files.directory);
    if (await owned.exists()) await owned.delete(recursive: true);
  });

  test('compute đọc JSON lồng nhau, thống kê đúng và ghi summary', () async {
    final result = await analyzeWithCompute(
      AnalysisRequest(
        inputPath: files.jsonPath,
        outputPath: files.computeOutput,
      ),
    );
    expect(result.records, 6);
    expect(result.averageScore, 10);
    expect(result.completedActivities, 9);
    expect(result.sampleNames, ['Sinh viên 1', 'Sinh viên 2', 'Sinh viên 3']);
    final summary = jsonDecode(await File(result.outputPath).readAsString());
    expect(summary, result.toJson());
  });

  test('spawn stream NDJSON cho kết quả giống compute và ghi file', () async {
    final expected = await analyzeWithCompute(
      AnalysisRequest(
        inputPath: files.jsonPath,
        outputPath: files.computeOutput,
      ),
    );
    final events = await analyzeWithIsolate(
      AnalysisRequest(
        inputPath: files.ndjsonPath,
        outputPath: files.isolateOutput,
      ),
    ).toList().timeout(const Duration(seconds: 10));
    expect(events.first, isA<AnalysisProgress>());
    final result = (events.last as AnalysisCompleted).result;
    expect(result.toJson(), expected.toJson());
    expect(
      jsonDecode(await File(result.outputPath).readAsString()),
      result.toJson(),
    );
  });

  test(
    'stream NDJSON xử lý được UTF-8 và bản ghi vắt qua chunk byte',
    () async {
      final record = {
        'name': List.filled(50000, 'ế').join(),
        'scores': {'theory': 80, 'practice': 100},
        'activities': [
          {'completed': true},
        ],
      };
      await File(files.ndjsonPath).writeAsString('${jsonEncode(record)}\n');
      final events = await analyzeWithIsolate(
        AnalysisRequest(
          inputPath: files.ndjsonPath,
          outputPath: files.isolateOutput,
        ),
      ).toList();
      final result = (events.last as AnalysisCompleted).result;
      expect(result.records, 1);
      expect(result.averageScore, 90);
      expect(result.sampleNames.single, record['name']);
    },
  );

  test('JSON sai được báo lỗi ở cả compute và spawn', () async {
    await File(files.jsonPath).writeAsString('invalid JSON');
    await File(files.ndjsonPath).writeAsString('invalid JSON\n');
    await expectLater(
      analyzeWithCompute(
        AnalysisRequest(
          inputPath: files.jsonPath,
          outputPath: files.computeOutput,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      analyzeWithIsolate(
        AnalysisRequest(
          inputPath: files.ndjsonPath,
          outputPath: files.isolateOutput,
        ),
      ).toList(),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'hủy nghe stream spawn giải phóng worker, không chờ tác vụ hoàn tất',
    () async {
      final event = await analyzeWithIsolate(
        AnalysisRequest(
          inputPath: files.ndjsonPath,
          outputPath: files.isolateOutput,
        ),
      ).first.timeout(const Duration(seconds: 5));
      expect(event, isA<AnalysisProgress>());
    },
  );

  test('tiến độ đúng số byte, tăng đơn điệu và luôn kết thúc ở 100%', () async {
    // Nhiều chunk giúp kiểm tra byte thực tế thay vì chỉ file một chunk.
    await File(files.jsonPath).writeAsBytes(List.filled(256 * 1024 + 13, 42));
    final events = await readFileProgress(
      File(files.jsonPath),
      updateInterval: Duration.zero,
    ).toList();
    expect(events.length, greaterThan(2));
    expect(events.first.fraction, 0);
    expect(events.last.fraction, 1);
    expect(events.last.bytesRead, 256 * 1024 + 13);
    expect(events.last.isComplete, isTrue);
    for (var i = 1; i < events.length; i++) {
      expect(
        events[i].bytesRead,
        greaterThanOrEqualTo(events[i - 1].bytesRead),
      );
      expect(events[i].fraction, inInclusiveRange(0.0, 1.0));
    }
  });

  test('giới hạn sự kiện trung gian vẫn giữ giá trị cuối', () async {
    final events = await readFileProgress(
      File(files.jsonPath),
      updateInterval: const Duration(days: 1),
    ).toList();
    expect(events.length, 2);
    expect(events.first.fraction, 0);
    expect(events.last.fraction, 1);
  });

  test('file rỗng hoàn tất 100%, file thiếu phát lỗi', () async {
    final events = await readFileProgress(File(files.emptyPath)).toList();
    expect(events.single.fraction, 1);
    expect(events.single.bytesRead, 0);
    expect(events.single.isComplete, isTrue);
    await expectLater(
      readFileProgress(File(files.missingPath)).toList(),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('lỗi mở file ở spawn được chuyển về UI qua stream', () async {
    await expectLater(
      analyzeWithIsolate(
        AnalysisRequest(
          inputPath: files.missingPath,
          outputPath: files.isolateOutput,
        ),
      ).toList().timeout(const Duration(seconds: 5)),
      throwsA(isA<StateError>()),
    );
  });
}
