import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../models/attendance.dart';

class ApiService {
  // Base URL của API server Flask
  // Đối với máy ảo Android, sử dụng 10.0.2.2 để tham chiếu localhost của máy tính
  static const String baseUrl = 'http://10.0.2.2:5001/api/student';
  
  // Helper method to get student ID from shared preferences
  Future<int?> _getStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('student_id');
  }
  
  // Register a new student
  Future<Map<String, dynamic>> registerStudent({
    required String name, 
    required String email, 
    required String password, 
    required String classCode,
  }) async {
    final uri = Uri.parse('$baseUrl/register');
    var request = http.MultipartRequest('POST', uri);
    
    request.fields['name'] = name;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['class_code'] = classCode;
    
    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      
      if (response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('student_id', data['student_id']);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  
  // Login student
  Future<Map<String, dynamic>> loginStudent(String email, String password) async {
    final uri = Uri.parse('$baseUrl/login');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('student_id', data['student_id']);
        return {
          'success': true, 
          'student': Student.fromJson(data),
        };
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  
  // Join a class using class code
  Future<Map<String, dynamic>> joinClass(String classCode) async {
    final studentId = await _getStudentId();
    if (studentId == null) {
      return {'success': false, 'message': 'Not logged in'};
    }
    
    final uri = Uri.parse('$baseUrl/join_class');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'student_id': studentId,
          'class_code': classCode,
        }),
      );
      
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  
  // Upload face images for recognition
  Future<Map<String, dynamic>> uploadFaces(List<File> images) async {
    final studentId = await _getStudentId();
    if (studentId == null) {
      return {'success': false, 'message': 'Not logged in'};
    }
    
    final uri = Uri.parse('$baseUrl/upload_faces');
    var request = http.MultipartRequest('POST', uri);
    request.fields['student_id'] = studentId.toString();
    
    // Add all images to the request
    for (var i = 0; i < images.length; i++) {
      final file = images[i];
      final stream = http.ByteStream(file.openRead());
      final length = await file.length();
      
      final multipartFile = http.MultipartFile(
        'images',
        stream,
        length,
        filename: 'face_image_$i.jpg',
      );
      
      request.files.add(multipartFile);
    }
    
    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  
  // Submit attendance with face recognition
  Future<Map<String, dynamic>> submitAttendance(File image, int classId) async {
    final studentId = await _getStudentId();
    if (studentId == null) {
      return {'success': false, 'message': 'Not logged in'};
    }
    
    final uri = Uri.parse('$baseUrl/submit_attendance');
    var request = http.MultipartRequest('POST', uri);
    request.fields['student_id'] = studentId.toString();
    request.fields['class_id'] = classId.toString();
    
    // Add the selfie image to the request
    final stream = http.ByteStream(image.openRead());
    final length = await image.length();
    
    final multipartFile = http.MultipartFile(
      'image',
      stream,
      length,
      filename: 'attendance_selfie.jpg',
    );
    
    request.files.add(multipartFile);
    
    try {
      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  
  // Get attendance history
  Future<Map<String, dynamic>> getAttendanceHistory() async {
    final studentId = await _getStudentId();
    if (studentId == null) {
      return {'success': false, 'message': 'Not logged in'};
    }
    
    final uri = Uri.parse('$baseUrl/attendance_history/$studentId');
    try {
      final response = await http.get(uri);
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        final attendanceList = (data['attendance'] as List)
          .map((item) => Attendance.fromJson(item))
          .toList();
          
        return {
          'success': true, 
          'student_name': data['student_name'],
          'attendance': attendanceList,
        };
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  
  // Get student profile
  Future<Map<String, dynamic>> getStudentProfile() async {
    final studentId = await _getStudentId();
    if (studentId == null) {
      return {'success': false, 'message': 'Not logged in'};
    }
    
    final uri = Uri.parse('$baseUrl/profile/$studentId');
    try {
      final response = await http.get(uri);
      final data = json.decode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true, 
          'student': Student.fromJson(data),
        };
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
  
  // Logout method
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('student_id');
  }
}