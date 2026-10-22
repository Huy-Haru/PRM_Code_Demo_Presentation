import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorageService {
  // Cấu hình mã hóa nâng cao cho từng nền tảng
  static const _androidOptions = AndroidOptions();


  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  // Định nghĩa các Key cố định
  static const String _keyAccessToken = 'access_token';


  Future<void> saveTokens({
    required String accessToken,
  }) async {
    await _storage.write(
      key: _keyAccessToken,
      value: accessToken,
    );
  }

  /// 2. Đọc Access Token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }


  /// 4. Kiểm tra người dùng đã đăng nhập hay chưa
  Future<bool> hasAccessToken() async {
    final token = await _storage.read(key: _keyAccessToken);
    return token != null && token.isNotEmpty;
  }

  /// 5. Xóa toàn bộ token khi Logout
  Future<void> clearAuthData() async {
    await _storage.delete(key: _keyAccessToken);
  }

  /// 6. Xóa toàn bộ dữ liệu đang lưu trong Secure Storage (dùng khi reset app)
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}