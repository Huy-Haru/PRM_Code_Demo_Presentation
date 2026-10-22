# Module 9 · Demo câu 08–09

Nguyễn Hải Huy · HE190724 · nhánh `HuyNHHE190724`.

Ứng dụng Flutter native minh họa hai nội dung:

- **Câu 08:** `compute()` và `Isolate.spawn()` thực hiện đọc file, parse JSON lồng nhau, tính thống kê và ghi file summary tại isolate phụ.
- **Câu 09:** `File.openRead()` phát chunk byte; `StreamBuilder` hiển thị phần trăm đọc theo thời gian thực, cập nhật trung gian khoảng 100 ms/lần.

## Chạy app

Yêu cầu Flutter kèm Dart 3.13.2 trở lên và thiết bị Android/iOS hoặc desktop đã cấu hình. Không chạy bằng Chrome/Web: demo dùng `dart:io` và `dart:isolate`. `compute` trên Web không tạo worker isolate như trên native.

```sh
cd code_demo_ex_08_09
flutter pub get
flutter devices
flutter run -d <device-id>
```

Không cần API key, mạng hay file ngoài. Bấm **Tạo dữ liệu mẫu** để tạo JSON mảng, NDJSON và file rỗng trong thư mục cache tạm riêng của app. Thư mục được hiển thị trên màn hình, file có thể bị hệ điều hành dọn dẹp. Đây là dữ liệu demo, không phải kho lưu bền vững. Bấm tạo lại để có bộ dữ liệu mới. 10.000 bản ghi phù hợp máy ít RAM; 50.000/100.000 dùng khi muốn quan sát file lớn hơn. Dung lượng hiển thị là số byte thực tế, không phải ước lượng.

## Kịch bản trình bày khoảng 8 phút

1. **Chuẩn bị (1 phút):** tạo 50.000 bản ghi. Mỗi bản ghi có thông tin cá nhân, điểm lý thuyết/thực hành và danh sách hoạt động. Chỉ ra JSON mảng và NDJSON cùng một bộ dữ liệu.
2. **compute (2 phút):** ở tab Câu 08, bấm **Chạy compute()**. Trong lúc chạy, bấm nút **UI đã nhận … lần chạm**, cuộn màn hình và quan sát spinner. Worker nhận path, mở file, `jsonDecode`, thống kê rồi ghi summary; UI chỉ nhận kết quả nhỏ. Mở phần code chính yếu và file `file_demo_service.dart`.
3. **spawn (2 phút):** bấm **Chạy Isolate.spawn()**. Worker đọc từng dòng NDJSON và gửi thông điệp tiến độ/kết quả/lỗi. So sánh số bản ghi, điểm trung bình và hoạt động hoàn thành với compute. Hai kết quả phải giống nhau. Có thể bấm **Hủy worker** khi đang chạy.
4. **Tiến độ (2 phút):** chuyển tab Câu 09, chọn JSON/NDJSON rồi bấm **Bắt đầu đọc file**. Mỗi chunk cộng `chunk.length`; tỷ lệ là số byte đã đọc chia tổng byte. Tiếp tục bấm counter để cho thấy UI vẫn phản hồi. Thử **File rỗng** (hoàn tất) và **File không tồn tại** (lỗi), sau đó chọn file hợp lệ và chạy lại.
5. **Chốt (1 phút):** async tránh chặn trong lúc chờ I/O; CPU parse vẫn cần worker khi đủ nặng. `compute` thuận tiện cho một kết quả, `spawn` cho phép giao tiếp và quản lý vòng đời worker. Tiến độ đọc byte khác tiến độ parse/import.

File trên SSD/cache có thể đọc xong trước 100 ms nên thanh tiến độ đi thẳng từ 0% tới 100%. Đó là hành vi đúng. App **không thêm delay giả** và không khẳng định số liệu thời gian là benchmark so sánh hai cách: chúng dùng định dạng khác nhau và chịu ảnh hưởng cache, thiết bị, startup isolate. Thời gian kết quả Câu 08 đo đọc + parse + ghi bên trong worker, chưa gồm thời gian tạo worker và truyền thông điệp.

## Code chính yếu nằm ở đâu?

| File | Nội dung |
| --- | --- |
| `lib/services/file_demo_service.dart` | Callback compute, worker NDJSON, SendPort/ReceivePort, generator tiến độ và tạo dữ liệu |
| `lib/models/demo_models.dart` | Request, result và các sự kiện tiến độ |
| `lib/screens/isolate_demo_panel.dart` | Chạy compute/spawn, nhận kết quả/lỗi, hủy subscription |
| `lib/screens/progress_demo_panel.dart` | Giữ stream trong State, StreamBuilder xử lý loading/lỗi/hoàn tất |
| `lib/screens/file_demo_home.dart` | Chuẩn bị dữ liệu và counter để thử UI |

### Câu 08: compute

```dart
// Callback top-level. Toàn bộ pipeline này chạy tại worker trên native.
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
final result = await compute(analyzeJsonFile, request);
```

`readAsString`/`jsonDecode` vẫn nạp toàn bộ JSON và object vào RAM. Isolate giúp UI phản hồi nhưng không tự giảm nhu cầu bộ nhớ.

### Câu 08: Isolate.spawn

```dart
final inbox = ReceivePort();
final worker = await Isolate.spawn(
  _ndjsonWorker,
  _WorkerRequest(request, inbox.sendPort),
  onError: inbox.sendPort,
  onExit: inbox.sendPort,
);
// Bên trong worker:
final lines = File(request.inputPath).openRead()
    .transform(utf8.decoder)
    .transform(const LineSplitter());
await for (final line in lines) {
  // jsonDecode(line), cộng thống kê và gửi tiến độ đã giới hạn tần suất.
}
// Main nhận AnalysisProgress / AnalysisCompleted / lỗi.
// finally yêu cầu hủy và chờ worker đóng file; kill là phương án dự phòng.
```

Mỗi dòng NDJSON là một JSON hoàn chỉnh. `utf8.decoder` và `LineSplitter` xử lý ranh giới ký tự/dòng giữa các chunk. **Không** gọi `jsonDecode` trên từng chunk tùy ý. Bộ nhớ vẫn phụ thuộc kích thước mỗi dòng/bản ghi. Không truyền BuildContext, Widget hay handle file đang mở giữa isolate. Worker chỉ gửi thống kê nhỏ, không gửi toàn bộ danh sách sinh viên về UI.

### Câu 09: stream và UI

```dart
// Trong sự kiện bấm nút, không tạo lại trong build().
setState(() => _stream = readFileProgress(file));

StreamBuilder<ReadProgress>(
  stream: _stream,
  builder: (context, snap) {
    if (snap.hasError) return Text('Lỗi đọc file');
    return LinearProgressIndicator(value: snap.data?.fraction ?? 0);
  },
);
```

`readFileProgress()` lấy `await file.length()`, đọc `await for (final chunk in file.openRead())`, cộng byte, phát sự kiện trung gian tối đa khoảng 10 lần/giây và luôn phát sự kiện hoàn tất. Không giữ các chunk trong một List lớn. File rỗng có giá trị hoàn tất 1.0; lỗi đọc đi vào stream. Phiên đọc mới dùng key mới để xóa snapshot cũ. StreamBuilder tự hủy subscription khi đổi stream hoặc dispose.

Demo Câu 09 chỉ đọc và đếm byte nhẹ trên Main Isolate. Nếu thêm xử lý CPU nặng, chuyển phần đó sang worker như Câu 08. Không parse JSON hoặc làm I/O trong builder. Dữ liệu file cần giữ ổn định trong suốt lần đọc; app khóa nút tạo file khi có tác vụ đang chạy.

## Kiểm tra

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Các test kiểm tra thống kê và summary, tính tương đương compute/spawn, UTF-8 qua ranh giới chunk, JSON lỗi, file thiếu/rỗng, tiến độ byte đơn điệu, throttling, hủy worker, điều hướng và bố cục điện thoại hẹp.

## Tài liệu chính thức

- [Flutter compute](https://api.flutter.dev/flutter/foundation/compute.html)
- [Dart Isolate.spawn](https://api.dart.dev/dart-isolate/Isolate/spawn.html)
- [Dart File.openRead](https://api.dart.dev/dart-io/File/openRead.html)
- [Flutter StreamBuilder](https://api.flutter.dev/flutter/widgets/StreamBuilder-class.html)
