# Module 9 · Demo câu 08–09

Nguyễn Hải Huy · HE190724 · nhánh `HuyNHHE190724`.

Hai file cần mở trong IDE khi thuyết trình:

| Câu | File | Thứ tự tìm trong file |
| --- | --- | --- |
| 08 | `lib/demo/cau_08_isolate.dart` | `C8.1` gọi compute → `C8.2` đọc/parse/ghi → chạy app; sau đó `C8.3` tạo worker → `C8.4` đọc từng dòng → `C8.5` gửi tiến độ |
| 09 | `lib/demo/cau_09_stream.dart` | `C9.1` đọc chunk → `C9.2` giới hạn nhịp → `C9.3` StreamBuilder → `C9.4` thanh tiến độ |

Mỗi mốc có chú thích **CHỈ VÀO ĐÂY** và **NÓI**. Các màn hình gọi trực tiếp những hàm và widget trong hai file này. Có thể dùng Ctrl+F để tìm `C8.1`, `C9.1`… thay vì nhớ số dòng.

## Chạy app

Yêu cầu Flutter kèm Dart 3.13.2 trở lên. Chạy trên Android/iOS hoặc desktop đã cấu hình, không chọn Chrome/Web vì demo dùng `dart:io` và `dart:isolate`.

```sh
cd code_demo_ex_08_09
flutter pub get
flutter run -d <device-id>
```

Không cần API key, mạng hay file bên ngoài. App tạo dữ liệu mẫu trong thư mục cache tạm riêng. File có thể bị hệ điều hành dọn dẹp; đây không phải kho lưu bền vững. Tạo lại dữ liệu khi cần.

## Trình bày câu 08

1. Trước giờ trình bày: chọn **50.000 bản ghi**, bấm **Tạo dữ liệu mẫu**. Dùng 10.000 nếu thiết bị ít RAM.
2. Mở `cau_08_isolate.dart`, chỉ **C8.1** và **C8.2**. Nói: “Main gửi đường dẫn sang worker. Worker tự đọc, parse, tính thống kê và ghi kết quả. Main chỉ nhận kết quả nhỏ về UI.”
3. Chuyển sang app, bấm **Chạy compute()**. Trong lúc còn chạy, thử counter hoặc cuộn màn hình; sau đó chỉ vào kết quả và file summary.
4. Quay lại code, chỉ **C8.3** ở `Isolate.spawn`. Chỉ **C8.4** ở `openRead`, `utf8.decoder`, `LineSplitter`, `jsonDecode(line)` và **C8.5** ở `send`.
5. Nói: “Worker đọc NDJSON theo từng dòng và gửi tiến độ về Main qua SendPort.” Chạy **Isolate.spawn()** trên app. Hai cách phải cho cùng số bản ghi và thống kê vì sử dụng cùng dữ liệu.

`compute` ở ví dụ native chạy cả đọc, parse và ghi tại isolate phụ. `readAsString` vẫn nạp toàn bộ JSON vào RAM. NDJSON yêu cầu mỗi dòng là một JSON hoàn chỉnh; khác JSON mảng nhiều dòng. Không parse trực tiếp một chunk byte tùy ý. Worker NDJSON giữ thống kê và từng dòng, nên bộ nhớ vẫn phụ thuộc kích thước dòng/bản ghi.

## Trình bày câu 09

1. Mở `cau_09_stream.dart`, chỉ **C9.1**: `openRead()` và `received += chunk.length`.
2. Chỉ **C9.2**: điều kiện 100 ms và `yield`. Nói: “File vẫn đọc liên tục, chỉ giới hạn số sự kiện tiến độ gửi tới UI.”
3. Kéo xuống **C9.3** và **C9.4**: StreamBuilder nhận stream rồi đưa `progress.fraction` vào thanh tiến độ. Công thức trong model là `bytesRead / totalBytes`.
4. Nếu được hỏi stream tạo ở đâu, tìm **C9.STATE** trong `lib/screens/progress_demo_panel.dart`: tạo khi bấm nút và giữ trong State, không tạo lại trong build.
5. Trên app, vào **Câu 09 · Tiến độ**, bấm **Bắt đầu đọc file**. Thử file rỗng và file không tồn tại rồi đọc lại file hợp lệ.

Phần này chỉ đọc và đếm byte nhẹ trên Main Isolate, không parse trong builder. StreamBuilder xử lý lỗi, loading và hoàn tất. File phải giữ ổn định trong lần đọc; app khóa tạo dữ liệu khi tác vụ đang chạy.

100% đọc byte chưa đồng nghĩa parse/import đã hoàn tất. File trên SSD/cache có thể đọc xong trước lần cập nhật 100 ms đầu tiên; app không thêm delay giả. Nhịp phát tiến độ khoảng 10 lần/giây không phải giới hạn FPS của UI. Thời gian thống kê Câu 08 đo bên trong worker, không gồm startup isolate, và hai định dạng khác nhau nên không dùng để kết luận cách nào luôn nhanh hơn.

## Các file hỗ trợ

- `lib/services/demo_data_service.dart`: tạo file mẫu, thống kê và ghi summary.
- `lib/services/isolate_worker_support.dart`: ReceivePort, xử lý lỗi/exit, hủy nhẹ nhàng và đợi worker đóng file; kill là dự phòng.
- `lib/models/demo_models.dart`: request, result, progress và công thức tỷ lệ.
- `lib/services/file_demo_service.dart`: export chung để giữ API dùng trong các test.

Không cần mở các file hỗ trợ để giải thích luồng chính. App vẫn có tạo dữ liệu, thử độ phản hồi UI, xử lý file rỗng/lỗi và hủy worker.

## Kiểm tra

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Test kiểm tra thống kê/summary, compute và spawn cho cùng kết quả, UTF-8 qua ranh giới chunk, JSON lỗi, file thiếu/rỗng, tiến độ byte, throttling, hủy worker, bố cục hẹp và stream ổn định khi widget cha dựng lại.

## Tài liệu chính thức

- [Flutter compute](https://api.flutter.dev/flutter/foundation/compute.html)
- [Dart Isolate.spawn](https://api.dart.dev/dart-isolate/Isolate/spawn.html)
- [Dart File.openRead](https://api.dart.dev/dart-io/File/openRead.html)
- [Flutter StreamBuilder](https://api.flutter.dev/flutter/widgets/StreamBuilder-class.html)
