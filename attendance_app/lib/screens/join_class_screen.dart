import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class JoinClassScreen extends StatefulWidget {
  const JoinClassScreen({Key? key}) : super(key: key);

  @override
  State<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends State<JoinClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _classCodeController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  bool _isJoining = false;
  String? _errorMessage;
  String? _successMessage;
  
  @override
  void dispose() {
    _classCodeController.dispose();
    super.dispose();
  }
  
  Future<void> _joinClass() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isJoining = true;
      _errorMessage = null;
      _successMessage = null;
    });
    
    final classCode = _classCodeController.text.trim();
    
    try {
      final result = await _apiService.joinClass(classCode);
      
      if (result['success']) {
        setState(() {
          _successMessage = 'Successfully joined ${result['data']['class_name']}';
          _classCodeController.clear();
          
          // Update the student's profile to reflect the new class
          Provider.of<AuthService>(context, listen: false).getProfile();
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to join class';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
      });
    } finally {
      setState(() {
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Class'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Join a New Class',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter the class code provided by your teacher to join a new class.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),
                
                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
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
                
                // Success message
                if (_successMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
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
                
                // Class code field
                TextFormField(
                  controller: _classCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Class Code',
                    hintText: 'Enter the 8-character code',
                    prefixIcon: Icon(Icons.class_),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the class code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),
                
                // Join class button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isJoining ? null : _joinClass,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: _isJoining
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
                              SizedBox(width: 16),
                              Text('Joining...'),
                            ],
                          )
                        : const Text('Join Class', style: TextStyle(fontSize: 16)),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'How to join a class:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Ask your teacher for the class code.',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        '2. Enter the code in the field above.',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        '3. Click "Join Class" to join the class.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}