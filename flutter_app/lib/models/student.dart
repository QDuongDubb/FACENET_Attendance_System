class Student {
  final int id;
  final String name;
  final String email;
  final int classId;
  final String className;
  final bool faceEncodingComplete;

  Student({
    required this.id,
    required this.name,
    required this.email,
    required this.classId,
    required this.className,
    required this.faceEncodingComplete,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['student_id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      classId: json['class_id'] ?? 0,
      className: json['class_name'] ?? 'Not Assigned', // Provide fallback for null class_name
      faceEncodingComplete: json['face_encoding_complete'] ?? false, // Default to false if null
    );
  }
}