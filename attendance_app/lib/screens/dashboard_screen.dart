import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'join_class_screen.dart';
import 'upload_faces_screen.dart';
import 'attendance_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Refresh the student profile when dashboard loads - but only once
    if (!_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Only try to get profile if we're not already logged in
        final authService = Provider.of<AuthService>(context, listen: false);
        if (authService.currentStudent == null && !authService.isLoading) {
          authService.getProfile();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              await authService.logout();
              
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, _) {
          // Handle loading state
          if (authService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Handle not logged in state (no redirects in build method)
          if (!authService.isLoggedIn) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Not logged in or session expired',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    child: const Text('Go to Login'),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                  )
                ],
              ),
            );
          }
          
          // Safe to use student data now
          final student = authService.currentStudent!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student info card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Name: ${student.name}'),
                        Text('Email: ${student.email}'),
                        Text('Class: ${student.className}'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text('Face Recognition Setup: '),
                            student.faceEncodingComplete
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 4),
                            Text(
                              student.faceEncodingComplete ? 'Complete' : 'Incomplete',
                              style: TextStyle(
                                color: student.faceEncodingComplete ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Dashboard options
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Grid of action buttons
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,                  children: [
                    // Take Attendance Card
                    _buildActionCard(
                      context: context,
                      title: 'Mark Attendance',
                      icon: Icons.camera_alt,
                      color: Colors.blue,
                      enabled: student.faceEncodingComplete,
                      message: student.faceEncodingComplete 
                        ? 'Mark your attendance with facial recognition' 
                        : 'Complete face recognition setup first',
                      onTap: () {
                        if (student.faceEncodingComplete) {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (_) => AttendanceScreen(classId: student.classId),
                            ),
                          );
                        }
                      },
                    ),
                    
                    // Settings Card
                    _buildActionCard(
                      context: context,
                      title: 'Connection Settings',
                      icon: Icons.settings,
                      color: Colors.grey.shade700,
                      enabled: true,
                      message: 'Configure server connection',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    
                    // Upload Face Images Card
                    _buildActionCard(
                      context: context,
                      title: 'Setup Face Recognition',
                      icon: Icons.face,
                      color: Colors.green,
                      enabled: true,
                      message: student.faceEncodingComplete 
                        ? 'Update your face images' 
                        : 'Upload your face images for attendance',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UploadFacesScreen(),
                          ),
                        );
                      },
                    ),
                    
                    // View Attendance History Card
                    _buildActionCard(
                      context: context,
                      title: 'Attendance History',
                      icon: Icons.history,
                      color: Colors.purple,
                      enabled: true,
                      message: 'View your attendance records',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const HistoryScreen(),
                          ),
                        );
                      },
                    ),
                    
                    // Join Another Class Card
                    _buildActionCard(
                      context: context,
                      title: 'Join Class',
                      icon: Icons.class_,
                      color: Colors.orange,
                      enabled: true,
                      message: 'Join another class with a code',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JoinClassScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required bool enabled,
    required String message,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      color: enabled ? Colors.white : Colors.grey[200],
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 36,
                color: enabled ? color : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: enabled ? Colors.black87 : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.black54 : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}