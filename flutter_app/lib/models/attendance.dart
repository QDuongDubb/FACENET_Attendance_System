class Attendance {
  final int id;
  final String date;
  final String status;
  final String? timestamp;
  final String className;

  Attendance({
    required this.id,
    required this.date,
    required this.status,
    this.timestamp,
    required this.className,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      date: json['date'],
      status: json['status'],
      timestamp: json['timestamp'],
      className: json['class_name'],
    );
  }
}