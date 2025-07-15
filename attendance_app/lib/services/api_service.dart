import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import '../models/student.dart';
import '../models/attendance.dart';

class ApiService {
  // Cấu hình URL kết nối đến backend Flask
  // Địa chỉ IP từ kết quả lệnh ipconfig - Wi-Fi adapter của máy tính
  static String baseUrl = 'http://192.168.240.15:5001/api/student';
  
  // Helper method để thiết lập địa chỉ IP của server
  static Future<void> setServerIP(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    baseUrl = 'http://$ip:5001/api/student';
  }
  
  // Helper method để lấy địa chỉ IP đã lưu
  static Future<String> getServerIP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_ip') ?? '192.168.240.15';
  }
  
  // Helper method để khởi tạo địa chỉ server từ SharedPreferences
  static Future<void> initServerAddress() async {
    final ip = await getServerIP();
    baseUrl = 'http://$ip:5001/api/student';
  }
  
  // Helper method to get student ID from shared preferences
  Future<int?> _getStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('student_id');
  }
  
  // Helper method to compress image before uploading
  Future<File> _compressImage(
    File file, {
    int quality = 70, 
    int maxWidth = 800, 
    int maxHeight = 800,
  }) async {
    // Create a target file path with _compressed added to the filename
    final dir = file.parent.path;
    final ext = p.extension(file.path);
    final filename = p.basenameWithoutExtension(file.path);
    final targetPath = '$dir/${filename}_compressed$ext';
    
    // Compress the image with specified quality and dimensions
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path, 
      targetPath,
      quality: quality,
      minWidth: maxWidth,
      minHeight: maxHeight,
    );
    
    return result != null ? File(result.path) : file;
  }
  
  // Helper method to fix image orientation
  Future<File> _fixExifRotation(File image) async {
    try {
      // Sử dụng flutter_exif_rotation để tự động sửa hướng ảnh dựa trên dữ liệu EXIF
      final File rotatedImage = await FlutterExifRotation.rotateImage(path: image.path);
      return rotatedImage;
    } catch (e) {
      print('Không thể sửa hướng ảnh: $e');
      return image; // Trả về ảnh gốc nếu không sửa được
    }
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
    
    // Tối ưu request dựa trên số lượng ảnh
    final bool isSingleImage = images.length == 1;
      // Áp dụng mức nén khác nhau dựa trên nguồn ảnh
    for (var i = 0; i < images.length; i++) {
      // Sửa hướng ảnh trước khi xử lý
      File fixedImage = await _fixExifRotation(images[i]);
      
      // Nén ảnh với chất lượng thấp hơn cho ảnh từ camera (nhận diện qua đường dẫn)
      final isCamera = fixedImage.path.contains('camera') || fixedImage.path.contains('CAM');
      
      // Nén ảnh với mức nén cao hơn (quality thấp hơn) cho ảnh camera
      final compressQuality = isCamera ? 50 : 70;
      
      // Nén mạnh hơn đối với ảnh từ camera
      final compressedFile = await _compressImage(
        fixedImage, 
        quality: compressQuality,
        maxWidth: isCamera ? 640 : 800,
        maxHeight: isCamera ? 640 : 800,
      );
      
      final stream = http.ByteStream(compressedFile.openRead());
      final length = await compressedFile.length();
      
      final multipartFile = http.MultipartFile(
        'images',
        stream,
        length,
        filename: 'face_image_$i.jpg',
      );
      
      request.files.add(multipartFile);
    }
    
    try {
      // Tăng thời gian timeout dựa trên số lượng ảnh
      final timeout = isSingleImage ? 
          const Duration(seconds: 30) : 
          const Duration(seconds: 60);
      
      // Gửi request với timeout phù hợp
      final client = http.Client();
      final response = await client.send(request).timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );
      
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      if (e is TimeoutException) {
        return {'success': false, 'message': 'Kết nối bị quá thời gian. Vui lòng thử lại hoặc sử dụng ảnh nhỏ hơn.'};
      }
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
      // Sửa hướng ảnh trước
    File fixedImage = await _fixExifRotation(image);
    
    // Compress the image before uploading
    final compressedFile = await _compressImage(fixedImage);
    
    // Add the compressed selfie image to the request
    final stream = http.ByteStream(compressedFile.openRead());
    final length = await compressedFile.length();
    
    final multipartFile = http.MultipartFile(
      'image',
      stream,
      length,
      filename: 'attendance_selfie.jpg',
    );
    
    request.files.add(multipartFile);
    request.persistentConnection = true;
    
    try {
      // Send with a timeout of 60 seconds
      final client = http.Client();
      final response = await client.send(request).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );
      
      final respStr = await response.stream.bytesToString();
      final data = json.decode(respStr);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message']};
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        return {'success': false, 'message': 'Kết nối bị quá thời gian. Vui lòng thử lại.'};
      }
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