from flask import Blueprint, request, jsonify, current_app, render_template
from flask_login import login_required, current_user
from app.models import Class, Student, StudentPhoto, Attendance
from app.utils.face_embedder import FaceEmbedder
from app import db
import os
import numpy as np
import cv2
from datetime import date, datetime, timezone
import pickle
import uuid
import io
import traceback

api = Blueprint('api', __name__)

# Initialize face embedder
face_embedder = None

def get_face_embedder():
    global face_embedder
    if face_embedder is None:
        try:
            face_embedder = FaceEmbedder()
            print("API blueprint: FaceEmbedder initialized successfully")
        except Exception as e:
            print(f"API blueprint: Error initializing face embedder: {e}")
            traceback.print_exc()
    return face_embedder

@api.route('/api/recognize', methods=['POST'])
@login_required
def recognize_face():
    if 'image' not in request.files:
        return jsonify({'success': False, 'message': 'No image provided'})
    
    class_id = request.form.get('class_id', type=int)
    if not class_id:
        return jsonify({'success': False, 'message': 'No class specified'})
    
    class_obj = Class.query.get_or_404(class_id)
    
    # Check if current user is the teacher of this class
    if (class_obj.teacher_id != current_user.id):
        return jsonify({'success': False, 'message': 'Unauthorized'})
    
    image_file = request.files['image']
    image_bytes = image_file.read()
    
    # Process image with face embedder
    embedder = get_face_embedder()
    if embedder is None:
        return jsonify({'success': False, 'message': 'Face recognition system not available'})
    
    # Get embeddings dictionary
    print(f"Looking for embeddings for teacher {current_user.id}, class {class_obj.name}")
    embeddings_dict = embedder.load_class_embeddings(current_user.id, class_obj.name)
    
    if not embeddings_dict:
        print(f"No embeddings found for teacher {current_user.id}, class {class_obj.name}")
        return jsonify({'success': False, 'message': 'No embeddings found for this class. Please add students with photos first.'})
    
    print(f"Found embeddings for {len(embeddings_dict)} students")
    
    # Detect faces in the image
    try:
        faces, img = embedder.detect_faces(image_bytes)
        print(f"Detected {len(faces)} faces in the uploaded image")
    except Exception as e:
        print(f"Face detection error: {str(e)}")
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Error detecting faces: {str(e)}'})
    
    if not faces:
        return jsonify({'success': False, 'message': 'No faces detected in the image'})
    
    # Process each face
    recognized_students = []
    face_locations = []
    
    for i, face in enumerate(faces):
        try:
            # Extract face location
            box = face['box']
            face_locations.append(box)
            
            # Preprocess face
            face_img = embedder.preprocess_face(img, face)
            
            # Get embedding
            embedding = embedder.get_embedding(face_img)
            
            # Compare with stored embeddings
            student_name, similarity = embedder.compare_faces(embedding, embeddings_dict)
            
            if student_name:
                print(f"Face {i+1}: Recognized as {student_name} with confidence {similarity:.4f}")
                # Try to find the student in the database
                student = Student.query.filter_by(name=student_name, class_id=class_id).first()
                if student:
                    recognized_students.append({
                        'id': student.id,
                        'name': student.name,
                        'confidence': float(similarity),
                        'face_index': i
                    })
            else:
                print(f"Face {i+1}: Not recognized, highest similarity was {similarity:.4f}")
        except Exception as e:
            print(f"Error processing face {i+1}: {str(e)}")
            traceback.print_exc()
    
    # Return results
    return jsonify({
        'success': True,
        'recognized': recognized_students,
        'face_locations': face_locations
    })

@api.route('/api/save-attendance', methods=['POST'])
@login_required
def save_attendance():
    class_id = request.form.get('class_id', type=int)
    if not class_id:
        return jsonify({'success': False, 'message': 'No class specified'})
    
    class_obj = Class.query.get_or_404(class_id)
    
    # Check if current user is the teacher of this class
    if class_obj.teacher_id != current_user.id:
        return jsonify({'success': False, 'message': 'Unauthorized'})
    
    # Get present students
    present_students = request.form.get('present_students', '[]')
    try:
        present_student_ids = set(map(int, eval(present_students)))
    except:
        return jsonify({'success': False, 'message': 'Invalid student data'})
    
    # Get attendance date
    attendance_date = request.form.get('date')
    if not attendance_date:
        attendance_date = date.today().isoformat()
    
    try:
        attendance_date = date.fromisoformat(attendance_date)
    except:
        return jsonify({'success': False, 'message': 'Invalid date format'})
    
    # Get all students in the class
    students = Student.query.filter_by(class_id=class_id).all()
    
    # Delete any existing attendance records for this class & date
    Attendance.query.filter_by(class_id=class_id, date=attendance_date).delete()
    
    # Create attendance records
    for student in students:
        status = student.id in present_student_ids
        attendance = Attendance(
            student_id=student.id,
            class_id=class_id,
            date=attendance_date,
            status=status
        )
        db.session.add(attendance)
    
    try:
        db.session.commit()
        return jsonify({'success': True, 'message': 'Attendance saved successfully'})
    except Exception as e:
        db.session.rollback()
        return jsonify({'success': False, 'message': f'Error saving attendance: {str(e)}'})

@api.route('/check-face', methods=['POST'])
def check_face():
    """API endpoint to check if a face is detected in an image"""
    if 'image' not in request.files:
        return jsonify({'success': False, 'message': 'No image provided'}), 400
        
    file = request.files['image']
    if not file.filename:
        return jsonify({'success': False, 'message': 'No image selected'}), 400
        
    try:
        # Read image data
        image_data = file.read()
        
        # Detect faces
        faces, _ = face_embedder.detect_faces(image_data)
        
        # Return results
        return jsonify({
            'success': True,
            'faces': [{
                'box': face['box'],
                'confidence': face['confidence']
            } for face in faces]
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

@api.route('/classes/<int:class_id>/attendance-data', methods=['GET'])
@login_required
def get_attendance_data(class_id):
    """API endpoint to fetch attendance data for a specific class"""
    try:
        # Verify that the current user has access to this class
        class_obj = Class.query.get_or_404(class_id)
        if class_obj.teacher_id != current_user.id:
            return jsonify({'success': False, 'message': 'Unauthorized'}), 403
            
        # Get the requested date or default to today
        requested_date = request.args.get('date')
        if requested_date:
            try:
                attendance_date = date.fromisoformat(requested_date)
            except ValueError:
                return jsonify({'success': False, 'message': 'Invalid date format'}), 400
        else:
            attendance_date = date.today()
        
        # Get attendance records for the class on the specified date
        attendance_records = Attendance.query.filter_by(
            class_id=class_id,
            date=attendance_date
        ).all()
        
        # Get all students in this class
        students = Student.query.filter_by(class_id=class_id).all()
        
        # Format attendance data
        attendance_data = []
        present_count = 0
        absent_count = 0
        
        # Create a mapping of student_id to attendance record
        attendance_map = {record.student_id: record for record in attendance_records}
        
        for student in students:
            attendance_record = attendance_map.get(student.id)
            is_present = attendance_record and attendance_record.status
            status = "Present" if is_present else "Absent"
            
            if is_present:
                present_count += 1
            else:
                absent_count += 1
            
            # Handle timestamp properly - append 'Z' to explicitly mark it as UTC
            timestamp_str = None
            if attendance_record and attendance_record.timestamp:
                # Ensure the timestamp is properly marked as UTC by adding Z suffix if needed
                timestamp_str = attendance_record.timestamp.replace(tzinfo=timezone.utc).isoformat()
                
            attendance_data.append({
                'student_id': student.id,
                'student_name': student.name,
                'status': is_present,
                'timestamp': timestamp_str
            })
            
        return jsonify({
            'success': True,
            'date': attendance_date.isoformat(),
            'attendance': attendance_data,
            'stats': {
                'total': len(students),
                'present': present_count,
                'absent': absent_count,
                'present_percent': round(present_count * 100 / len(students)) if students else 0
            }
        })
        
    except Exception as e:
        print(f"Error fetching attendance data: {str(e)}")
        traceback.print_exc()
        return jsonify({'success': False, 'message': f'Error fetching attendance data: {str(e)}'}), 500

@api.route('/api/get-attendance-data', methods=['GET'])
@login_required
def get_attendance_data_api():  # Changed function name from get_attendance_data to get_attendance_data_api
    class_id = request.args.get('class_id', type=int)
    attendance_date_str = request.args.get('date')
    
    if not class_id:
        return jsonify({'success': False, 'message': 'No class specified'})
    
    class_obj = Class.query.get_or_404(class_id)
    
    # Check if current user is the teacher of this class
    if class_obj.teacher_id != current_user.id:
        return jsonify({'success': False, 'message': 'Unauthorized'})
    
    # If no date is provided, use today's date
    if attendance_date_str:
        try:
            attendance_date = date.fromisoformat(attendance_date_str)
        except ValueError:
            return jsonify({'success': False, 'message': 'Invalid date format'})
    else:
        attendance_date = date.today()
    
    # Get all students in this class
    students = Student.query.filter_by(class_id=class_id).all()
    
    # Get attendance records for this class and date
    attendance_records = Attendance.query.filter_by(
        class_id=class_id, 
        date=attendance_date
    ).all()
    
    # Create a dictionary for faster lookup
    attendance_dict = {record.student_id: record.status for record in attendance_records}
    
    # Build student data including attendance status
    student_data = []
    for student in students:
        student_data.append({
            'id': student.id,
            'name': student.name,
            'present': attendance_dict.get(student.id, False)
        })
    
    return jsonify({
        'success': True,
        'date': attendance_date.isoformat(),
        'class_name': class_obj.name,
        'students': student_data
    })