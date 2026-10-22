import 'dart:async';

import 'package:code_demo_ex_08_09/main.dart';
import 'package:code_demo_ex_08_09/models/demo_models.dart';
import 'package:code_demo_ex_08_09/screens/progress_demo_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('màn hình chuẩn bị, counter và điều hướng hai câu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const FileDemoApp());

    expect(find.text('File Lab • Module 9'), findsOneWidget);
    expect(find.text('Tạo dữ liệu mẫu'), findsOneWidget);
    final compute = tester.widget<FilledButton>(
      find.byKey(const Key('run-compute')),
    );
    expect(compute.onPressed, isNull);

    await tester.ensureVisible(find.byKey(const Key('ui-counter')));
    await tester.tap(find.byKey(const Key('ui-counter')));
    await tester.pump();
    expect(find.text('UI đã nhận 1 lần chạm'), findsOneWidget);

    await tester.tap(find.text('Câu 09 · Tiến độ'));
    await tester.pumpAndSettle();
    expect(
      find.text('Câu 09 · File.openRead() + StreamBuilder'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('read-file')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bố cục trên điện thoại hẹp không tràn ngang', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const FileDemoApp());
    await tester.tap(find.text('Câu 09 · Tiến độ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'StreamBuilder hiện tiến độ và không đọc lại khi widget cha rebuild',
    (tester) async {
      const files = DemoFiles(
        directory: 'demo',
        jsonPath: 'demo/students.json',
        ndjsonPath: 'demo/students.ndjson',
        emptyPath: 'demo/empty',
        recordCount: 2,
        jsonBytes: 100,
        ndjsonBytes: 100,
      );
      final source = StreamController<ReadProgress>();
      var readCalls = 0;
      final running = <bool>[];
      Widget host() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgressDemoPanel(
              files: files,
              locked: false,
              onRunningChanged: running.add,
              readProgress: (_) {
                readCalls++;
                return source.stream;
              },
            ),
          ),
        ),
      );
      try {
        await tester.pumpWidget(host());
        await tester.ensureVisible(find.byKey(const Key('read-file')));
        await tester.tap(find.byKey(const Key('read-file')));
        await tester.pump();
        source.add(
          const ReadProgress(
            bytesRead: 50,
            totalBytes: 100,
            elapsedMicroseconds: 100000,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('50%'), findsOneWidget);
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();
        expect(readCalls, 1);
        expect(running, [true]);
        source.add(
          const ReadProgress(
            bytesRead: 100,
            totalBytes: 100,
            elapsedMicroseconds: 200000,
            isComplete: true,
          ),
        );
        unawaited(source.close());
        await tester.pumpAndSettle();
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('Đã đọc xong toàn bộ byte.'), findsOneWidget);
        expect(running, [true, false]);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        if (!source.isClosed) unawaited(source.close());
      }
    },
  );
}
