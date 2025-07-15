import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  final int classId;

  const AttendanceScreen({
    Key? key,
    required this.classId,
  }) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  bool _isTakingPicture = false;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;
  bool _cameraPermissionDenied = false;
  
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _initCamera();
    } else {
      setState(() {
        _cameraPermissionDenied = true;
        _errorMessage = 'Camera permission is required to mark attendance';
      });
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on device';
        });
        return;
      }
      
      // Use front camera if available
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
        _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low, // Sử dụng độ phân giải thấp hơn
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      
      _initializeControllerFuture = _cameraController?.initialize();
      await _initializeControllerFuture;
      
      if (mounted) {
        setState(() {
          // Camera initialized successfully
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      setState(() {
        _errorMessage = 'Camera is not ready';
      });
      return;
    }

    try {
      setState(() {
        _isTakingPicture = true;
        _errorMessage = null;
        _successMessage = null;
      });

      // Ensure camera is initialized
      await _initializeControllerFuture;
      
      // Take picture
      final image = await _cameraController!.takePicture();
      
      // Submit attendance with the image
      await _submitAttendance(File(image.path));
    } catch (e) {
      setState(() {
        _errorMessage = 'Error taking picture: $e';
        _isTakingPicture = false;
      });
    }
  }

  Future<void> _submitAttendance(File imageFile) async {
    try {
      setState(() {
        _isProcessing = true;
        _isTakingPicture = false;
      });
      
      final result = await _apiService.submitAttendance(
        imageFile,
        widget.classId,
      );
      
      if (result['success']) {
        setState(() {
          _successMessage = 'Attendance marked successfully!';
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to mark attendance';
          _successMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _successMessage = null;
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
      
      // Delete temporary image file
      try {
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (e) {
        // Ignore errors when deleting temporary files
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
      ),
      body: Column(
        children: [
          // Camera permission denied message
          if (_cameraPermissionDenied)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.red.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Camera permission is required',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      openAppSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ),

          // Status messages
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.red.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          
          if (_successMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              color: Colors.green.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _successMessage = null;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Mark Again'),
                  ),
                ],
              ),
            ),
          
          // Camera preview
          Expanded(
            child: (_errorMessage != null || _successMessage != null)
                ? const Center(
                    child: Icon(
                      Icons.camera_alt,
                      size: 120,
                      color: Colors.grey,
                    ),
                  )
                : _buildCameraPreview(),
          ),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              children: [
                const Text(
                  'Position your face in the frame',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ensure your face is well-lit and clearly visible',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_cameraController?.value.isInitialized ?? false) &&
                            !_isTakingPicture &&
                            !_isProcessing &&
                            _errorMessage == null &&
                            _successMessage == null
                        ? _takePicture
                        : null,
                    child: _isProcessing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Processing...'),
                            ],
                          )
                        : _isTakingPicture
                            ? const Text('Taking Picture...')
                            : const Text('Take Picture & Mark Attendance'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraController == null || _initializeControllerFuture == null) {
      return const Center(
        child: Text('Camera initialization failed'),
      );
    }

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CameraPreview(_cameraController!),
                
                // Face overlay
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue,
                      width: 3,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
      },
    );
  }
}