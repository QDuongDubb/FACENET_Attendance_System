# Face Recognition Attendance System

A full stack web application for tracking attendance using face recognition with David Sandberg's FaceNet implementation.

## Features

- Teacher registration and authentication
- Class and student management
- Face recognition-based attendance using FaceNet and MTCNN
- Webcam integration for capturing student faces
- Attendance records and reporting

## Installation

1. Clone the repository:
```
git clone <repository-url>
cd ATTENDANCE_2
```

2. Download the pre-trained FaceNet model:
   - Download the model from https://drive.google.com/file/d/1EXPBSXwTaqrSC0OhUdXNmKSh9qJUQ55-/view
   - Extract the downloaded file
   - Place the `20180402-114759` folder in the root directory of the project

3. Create a virtual environment and activate it:
```
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

4. Install the required dependencies:
```
pip install -r requirements.txt
```

5. Run the application:
```
python run.py
```

## Usage

1. Open a web browser and navigate to `http://localhost:5000`
2. Register as a teacher
3. Create classes and add students with at least 2 photos per student
4. Use the attendance feature to take attendance using face recognition:
   - Start the camera
   - Position students' faces in the frame
   - Capture the image
   - Save attendance records

## Project Structure

- `/app` - Flask application code
- `/20180402-114759` - FaceNet pre-trained model
- `/embeddings` - Stored face embeddings
- `/student_images` - Student photos organized by teacher/class/student
- `/static` - Static assets (CSS, JS)
- `/templates` - HTML templates
- `run.py` - Application entry point

## Technologies Used

- Python 3.6+
- Flask - Web framework
- FLutter - Mobile framework
- TensorFlow - For FaceNet model
- MTCNN - For face detection
- OpenCV - For image processing
- SQLAlchemy - ORM for database
- Bootstrap 5 - Frontend styling
- JavaScript - Client-side functionality

## License

MIT

## Acknowledgements

- [David Sandberg's FaceNet Implementation](https://github.com/davidsandberg/facenet)
- [MTCNN Face Detection](https://github.com/ipazc/mtcnn)
- [Flask Framework](https://flask.palletsprojects.com/)
