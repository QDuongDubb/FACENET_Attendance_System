import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class UploadFacesScreen extends StatefulWidget {
  const UploadFacesScreen({Key? key}) : super(key: key);

  @override
  State<UploadFacesScreen> createState() => _UploadFacesScreenState();
}

class _UploadFacesScreenState extends State<UploadFacesScreen> {
  final ApiService _apiService = ApiService();
  final List<File> _selectedImages = [];
  bool _isUploading = false;
  String? _errorMessage;
  String? _successMessage;  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 640,  // Giảm kích thước tối đa
      maxHeight: 640, // Giảm kích thước tối đa
      imageQuality: 70, // Giảm chất lượng để file nhỏ hơn
    );

    if (image != null) {
      try {
        // Hiển thị ảnh đã chụp để xác nhận
        final File imageFile = File(image.path);
        
        // Xử lý định hướng ảnh ngay tại đây nếu cần
        setState(() {
          _selectedImages.add(imageFile);
          _successMessage = 'Đã thêm ảnh. Hãy kiểm tra xem ảnh đã đúng hướng chưa.';
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Lỗi khi xử lý ảnh: $e';
        });
      }
    }
  }
  Future<void> _selectFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80, // Ảnh thư viện thường đã được nén, có thể giữ chất lượng cao hơn
    );

    if (images.isNotEmpty) {
      try {
        List<File> fixedImages = [];
        for (var image in images) {
          // Sửa định hướng cho mỗi ảnh
          File imageFile = File(image.path);
          File fixedImage = await _fixImageOrientation(imageFile);
          fixedImages.add(fixedImage);
        }
        
        setState(() {
          _selectedImages.addAll(fixedImages);
          _successMessage = 'Đã thêm ${fixedImages.length} ảnh';
        });
      } catch (e) {
        setState(() {
          _errorMessage = 'Lỗi khi xử lý ảnh: $e';
        });
      }
    }
  }

  // Phương thức sửa định hướng ảnh
  Future<File> _fixImageOrientation(File imageFile) async {
    try {
      // Sửa định hướng ảnh dựa vào metadata EXIF
      final File rotatedImage = await FlutterExifRotation.rotateImage(path: imageFile.path);
      return rotatedImage;
    } catch (e) {
      print('Không thể sửa định hướng ảnh: $e');
      return imageFile; // Nếu không sửa được, trả về ảnh gốc
    }
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one image';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Kiểm tra nguồn gốc của ảnh - ảnh camera cần được xử lý riêng
      List<File> cameraImages = [];
      List<File> galleryImages = [];
      
      for (var image in _selectedImages) {
        // Sử dụng tên file để xác định nguồn ảnh (camera thường có đường dẫn khác biệt)
        if (image.path.contains('camera') || image.path.contains('CAM')) {
          cameraImages.add(image);
        } else {
          galleryImages.add(image);
        }
      }
      
      bool success = false;
      
      // Xử lý các ảnh thư viện (có thể upload cùng lúc)
      if (galleryImages.isNotEmpty) {
        final galleryResult = await _apiService.uploadFaces(galleryImages);
        success = galleryResult['success'];
        
        if (!success) {
          setState(() {
            _errorMessage = galleryResult['message'] ?? 'Không thể tải lên ảnh từ thư viện';
          });
          return;
        }
      }
      
      // Xử lý các ảnh camera riêng biệt từng ảnh một
      if (cameraImages.isNotEmpty) {
        int successCount = 0;
        
        for (var image in cameraImages) {
          // Sửa định hướng ảnh trước khi tải lên
          final fixedImage = await _fixImageOrientation(image);
          
          final cameraResult = await _apiService.uploadFaces([fixedImage]);
          if (cameraResult['success']) {
            successCount++;
          } else {
            // Nếu một ảnh bị lỗi, tiếp tục xử lý ảnh tiếp theo
            print('Lỗi khi tải ảnh camera: ${cameraResult['message']}');
          }
          
          // Cập nhật tiến trình
          setState(() {
            _successMessage = 'Đã tải $successCount/${cameraImages.length} ảnh camera';
          });
        }
        
        success = successCount > 0;
      }
      
      if (success) {
        setState(() {
          _successMessage = 'Images uploaded successfully';
          _selectedImages.clear();
          
          // Update face encoding status in auth service
          Provider.of<AuthService>(context, listen: false)
              .updateFaceEncodingStatus(true);
        });
      } else {
        setState(() {
          _errorMessage = _errorMessage ?? 'An error occurred during upload';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Face Images'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            const Text(
              'Upload Your Face Images',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please upload 3-5 clear photos of your face for the attendance system. Make sure your face is well-lit and clearly visible.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            
            // Status messages
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Selected images grid
            Expanded(
              child: _selectedImages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No images selected',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImages[index],
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Remove button
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedImages.removeAt(index);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            
            // Image selection buttons
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _takePicture,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _selectFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Upload button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading || _selectedImages.isEmpty
                    ? null
                    : _uploadImages,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: _isUploading
                    ? Row(
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
                          SizedBox(width: 16),
                          Text(_successMessage != null && _successMessage!.contains('Đã tải') ? 
                            _successMessage! : 'Đang tải lên...'),
                        ],
                      )
                    : Text(
                        'Tải lên ${_selectedImages.length} ảnh',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
            
            if (_isUploading && _selectedImages.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Quá trình tải ảnh và tạo embedding có thể mất vài phút, vui lòng chờ...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}