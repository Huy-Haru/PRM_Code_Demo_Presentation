import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String name;
  final int age;
  final String email;

  User({required this.name, required this.age, required this.email});

  // chuyển Object thành Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'email': email,
    };
  }

  // khởi tạo Object từ Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      name: map['name'] as String,
      age: map['age'] as int,
      email: map['email'] as String,
    );
  }

  // chuyển đổi sang JSON String
  String toJson() => jsonEncode(toMap());

  factory User.fromJson(String source) => User.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

// lưu Object
Future<void> saveUser(User user) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user_data', user.toJson());
}

// lấy Object
Future<User?> getUser() async {
  final prefs = await SharedPreferences.getInstance();
  final userString = prefs.getString('user_data');
  if (userString == null) return null;
  return User.fromJson(userString);
}