import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  List<Attendance> _attendanceRecords = [];
  String _studentName = '';
  
  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }
  
  Future<void> _loadAttendanceHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final result = await _apiService.getAttendanceHistory();
      
      if (result['success']) {
        setState(() {
          _attendanceRecords = result['attendance'];
          _studentName = result['student_name'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attendance history: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendanceHistory,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAttendanceHistory,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_attendanceRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No attendance records found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your attendance history will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // Student name and stats header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.withOpacity(0.1),
          child: Column(
            children: [
              Text(
                'Attendance Records for $_studentName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard(
                    'Total Records',
                    _attendanceRecords.length.toString(),
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Present',
                    _attendanceRecords.where((a) => a.status == 'Present').length.toString(),
                    Colors.green,
                  ),
                  _buildStatCard(
                    'Absent',
                    _attendanceRecords.where((a) => a.status == 'Absent').length.toString(),
                    Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // List of records
        Expanded(
          child: ListView.builder(
            itemCount: _attendanceRecords.length,
            itemBuilder: (context, index) {
              final record = _attendanceRecords[index];
              final date = DateTime.parse(record.date);
              final formattedDate = DateFormat('EEE, MMM d, yyyy').format(date);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: record.status == 'Present'
                        ? Colors.green
                        : Colors.red,
                    child: Icon(
                      record.status == 'Present'
                          ? Icons.check
                          : Icons.close,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    formattedDate,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Class: ${record.className}'),
                      if (record.timestamp != null)
                        Text(
                          'Time: ${DateFormat('hh:mm a').format(DateTime.parse(record.timestamp!).toLocal())}',
                        ),
                    ],
                  ),
                  trailing: Text(
                    record.status,
                    style: TextStyle(
                      color: record.status == 'Present'
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}