import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  Student? _currentStudent;
  bool _loading = false;
  String? _error;
  bool _profileLoadAttempted = false; // Track if we've already tried loading the profile
  final ApiService _apiService = ApiService();
  
  Student? get currentStudent => _currentStudent;
  bool get isLoggedIn => _currentStudent != null;
  bool get isLoading => _loading;
  String? get error => _error;
  
  // Register a new student
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String classCode,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _apiService.registerStudent(
        name: name,
        email: email,
        password: password,
        classCode: classCode,
      );
      
      _loading = false;
      
      if (result['success']) {
        // After registration, get the student profile
        await getProfile();
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _loading = false;
      _error = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Login student
  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    
    try {
      final result = await _apiService.loginStudent(email, password);
      
      _loading = false;
      
      if (result['success']) {
        _currentStudent = result['student'];
        _profileLoadAttempted = true;
        
        // Save face encoding status to SharedPreferences
        await _saveFaceEncodingStatus(_currentStudent!.faceEncodingComplete);
        
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _loading = false;
      _error = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Get student profile
  Future<bool> getProfile() async {
    // Check if we can get the face encoding status from SharedPreferences first
    final bool? savedFaceEncodingStatus = await _getFaceEncodingStatus();
    
    // Avoid multiple attempts to load profile in quick succession
    if (_loading) {
      return _currentStudent != null;
    }
    
    // If we already have the student and face encoding status, no need to call the API
    if (_currentStudent != null && savedFaceEncodingStatus != null) {
      // Update the current student with the saved face encoding status
      if (_currentStudent!.faceEncodingComplete != savedFaceEncodingStatus) {
        _currentStudent = Student(
          id: _currentStudent!.id,
          name: _currentStudent!.name,
          email: _currentStudent!.email,
          classId: _currentStudent!.classId,
          className: _currentStudent!.className,
          faceEncodingComplete: savedFaceEncodingStatus,
        );
        notifyListeners();
      }
      return true;
    }
    
    _loading = true;
    notifyListeners();
    
    try {
      final result = await _apiService.getStudentProfile();
      
      _loading = false;
      _profileLoadAttempted = true;
      
      if (result['success']) {
        _currentStudent = result['student'];
        
        // Save face encoding status to SharedPreferences
        await _saveFaceEncodingStatus(_currentStudent!.faceEncodingComplete);
        
        notifyListeners();
        return true;
      } else {
        _error = result['message'];
        notifyListeners();
        return false;
      }
    } catch (e) {
      _loading = false;
      _error = 'Network error: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
  
  // Save face encoding status to SharedPreferences
  Future<void> _saveFaceEncodingStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('face_encoding_complete', status);
  }
  
  // Get face encoding status from SharedPreferences
  Future<bool?> _getFaceEncodingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('face_encoding_complete');
  }
  
  // Update face encoding status
  Future<void> updateFaceEncodingStatus(bool status) async {
    if (_currentStudent != null) {
      _currentStudent = Student(
        id: _currentStudent!.id,
        name: _currentStudent!.name,
        email: _currentStudent!.email,
        classId: _currentStudent!.classId,
        className: _currentStudent!.className,
        faceEncodingComplete: status,
      );
      
      // Save the updated status to SharedPreferences
      await _saveFaceEncodingStatus(status);
      
      notifyListeners();
    }
  }
  
  // Logout
  Future<void> logout() async {
    await _apiService.logout();
    
    // Clear face encoding status when logging out
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('face_encoding_complete');
    
    _currentStudent = null;
    _profileLoadAttempted = false;
    notifyListeners();
  }
  
  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  // Reset profile load attempted flag (use when navigating back to login)
  void resetProfileLoadAttempted() {
    _profileLoadAttempted = false;
  }
}