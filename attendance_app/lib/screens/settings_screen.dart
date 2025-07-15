import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _ipController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentIP();
  }

  Future<void> _loadCurrentIP() async {
    final currentIP = await ApiService.getServerIP();
    _ipController.text = currentIP;
  }

  Future<void> _saveIP() async {
    final ip = _ipController.text.trim();
    
    // Kiểm tra IP hợp lệ
    final ipRegex = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    if (!ipRegex.hasMatch(ip)) {
      setState(() {
        _errorMessage = 'Địa chỉ IP không hợp lệ';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ApiService.setServerIP(ip);
      setState(() {
        _successMessage = 'Đã lưu địa chỉ IP server: $ip';
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi lưu IP: $e';
        _successMessage = null;
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt kết nối'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cài đặt địa chỉ IP Server',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nhập địa chỉ IP của máy tính đang chạy Flask server (ví dụ: 192.168.1.5)',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ IP Server',
                hintText: 'Ví dụ: 192.168.1.5',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveIP,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Text('Lưu cài đặt'),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'Lưu ý: Điện thoại và máy tính phải kết nối cùng một mạng (Wi-Fi) để có thể giao tiếp với nhau.',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text(
              'Hướng dẫn:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            const Text(
              '1. Đảm bảo máy tính đang chạy server Flask (python run.py)\n'
              '2. Kiểm tra địa chỉ IP của máy tính bằng lệnh "ipconfig" (Windows) hoặc "ifconfig" (Mac/Linux)\n'
              '3. Nhập địa chỉ IP của máy tính vào trường trên\n'
              '4. Đảm bảo điện thoại và máy tính kết nối cùng mạng Wi-Fi',
              style: TextStyle(fontSize: 14),
            ),
            
            const Spacer(),
            
            // Test connection button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Test kết nối
                  setState(() {
                    _isSaving = true;
                    _errorMessage = null;
                    _successMessage = null;
                  });
                  
                  try {
                    final client = await ApiService().getStudentProfile();
                    if (client['success']) {
                      setState(() {
                        _successMessage = 'Kết nối thành công đến server!';
                      });
                    } else {
                      setState(() {
                        _errorMessage = 'Kết nối thất bại: ${client['message']}';
                      });
                    }
                  } catch (e) {
                    setState(() {
                      _errorMessage = 'Lỗi kết nối: $e';
                    });
                  } finally {
                    setState(() {
                      _isSaving = false;
                    });
                  }
                },
                icon: const Icon(Icons.network_check),
                label: const Text('Kiểm tra kết nối'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
