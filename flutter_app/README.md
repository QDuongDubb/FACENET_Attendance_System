# Student Attendance Mobile App

A cross-platform Flutter mobile application for students to mark attendance using facial recognition, integrated with the Flask backend attendance system.

## Features

- **Student Authentication**: Register and login with email/password
- **Class Management**: Join classes using class codes provided by teachers
- **Face Recognition**: Upload face images to set up facial recognition
- **Attendance Marking**: Take selfies to mark attendance in real-time
- **History Tracking**: View complete attendance history

## Prerequisites

- Flutter SDK (2.17.0 or higher)
- Dart SDK (2.17.0 or higher)
- Android Studio / Xcode for mobile device emulation
- A running instance of the Flask backend API

## Getting Started

### 1. Setup Flutter

If you haven't installed Flutter yet:

```bash
# Download Flutter SDK from flutter.dev and add to path
flutter doctor  # Verify installation and fix any issues
```

### 2. Clone the Repository

```bash
cd /path/to/project
git clone https://github.com/your-username/ATTENDANCE_2.git
cd ATTENDANCE_2/flutter_app
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Configure API Endpoint

In `lib/services/api_service.dart`, update the `baseUrl` variable to point to your Flask API server:

```dart
static const String baseUrl = 'http://your-api-server-address:5000/api/student';
```

- For Android Emulator: Use `10.0.2.2` instead of `localhost`
- For iOS Simulator: Use `localhost` or `127.0.0.1`
- For physical devices: Use your computer's actual IP address on the network

### 5. Run the App

```bash
flutter run
```

## Project Structure

- `lib/main.dart` - Entry point for the app
- `lib/models/` - Data models for student and attendance
- `lib/screens/` - UI screens for different app features
- `lib/services/` - API and authentication services
- `lib/widgets/` - Reusable UI components

## API Integration

The app connects to the Flask backend through REST API endpoints:

- `/api/student/register` - Student registration
- `/api/student/login` - Student authentication
- `/api/student/join_class` - Join a class with code
- `/api/student/upload_faces` - Upload face images for recognition
- `/api/student/submit_attendance` - Submit attendance with facial verification
- `/api/student/attendance_history` - Get attendance records
- `/api/student/profile` - Get student profile information

## Building for Production

### Android

```bash
flutter build apk --release
# The APK file will be at build/app/outputs/flutter-apk/app-release.apk
```

### iOS

```bash
flutter build ios --release
# Open Xcode to archive and distribute the app
```