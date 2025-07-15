from flask import Blueprint, request, jsonify
from flask_login import login_user, current_user, logout_user, login_required
from app import db
from app.models import Student, Class, StudentPhoto, Attendance
from werkzeug.utils import secure_filename
from app.utils.face_embedder import FaceEmbedder
import os
import uuid
from datetime import datetime, date, timezone
import json
import glob
import pickle

student_api = Blueprint('student_api', __name__)
face_embedder = FaceEmbedder()

# Helper function to save uploaded images
def save_student_image(file, student_id, class_id):
    if not file:
        return None
    
    # Create directory structure if it doesn't exist
    student_dir = os.path.join('static', 'uploads', 'student_images', str(class_id), str(student_id))
    os.makedirs(student_dir, exist_ok=True)
    
    # Generate a unique filename
    original_filename = secure_filename(file.filename)
    unique_id = str(uuid.uuid4())
    timestamp = str(int(datetime.now().timestamp() * 1000000000))
    filename = f"{unique_id}_{timestamp}.jpg"
    
    # Save the file
    file_path = os.path.join(student_dir, filename)
    file.save(file_path)
    
    return filename

# Student registration
@student_api.route('/register', methods=['POST'])
def register():
    try:
        data = request.form
        class_code = data.get('class_code')
        name = data.get('name')
        email = data.get('email')
        password = data.get('password')
        
        if not class_code or not name or not email or not password:
            return jsonify({'success': False, 'message': 'Missing required fields'}), 400
        
        # Check if class exists
        class_obj = Class.query.filter_by(class_code=class_code).first()
        if not class_obj:
            return jsonify({'success': False, 'message': 'Invalid class code'}), 404
        
        # Check if email is already registered
        if Student.query.filter_by(email=email).first():
            return jsonify({'success': False, 'message': 'Email already registered'}), 409
        
        # Create new student
        new_student = Student(name=name, email=email, class_id=class_obj.id)
        new_student.set_password(password)
        
        db.session.add(new_student)
        db.session.commit()
        
        return jsonify({
            'success': True,
            'message': 'Registration successful',
            'student_id': new_student.id
        }), 201
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Student login
@student_api.route('/login', methods=['POST'])
def login():
    try:
        data = request.json
        email = data.get('email')
        password = data.get('password')
        
        if not email or not password:
            return jsonify({'success': False, 'message': 'Missing email or password'}), 400
        
        # Find student by email
        student = Student.query.filter_by(email=email).first()
        
        if not student or not student.check_password(password):
            return jsonify({'success': False, 'message': 'Invalid email or password'}), 401
        
        # Login successful
        login_user(student)
        
        return jsonify({
            'success': True,
            'message': 'Login successful',
            'student_id': student.id,
            'name': student.name,
            'class_id': student.class_id,
            'class_name': student.class_ref.name,
            'face_encoding_complete': student.face_encoding_complete
        }), 200
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Join class
@student_api.route('/join_class', methods=['POST'])
def join_class():
    try:
        data = request.json
        student_id = data.get('student_id')
        class_code = data.get('class_code')
        
        if not student_id or not class_code:
            return jsonify({'success': False, 'message': 'Missing required fields'}), 400
        
        # Check if student exists
        student = Student.query.get(student_id)
        if not student:
            return jsonify({'success': False, 'message': 'Student not found'}), 404
        
        # Check if class exists
        class_obj = Class.query.filter_by(class_code=class_code).first()
        if not class_obj:
            return jsonify({'success': False, 'message': 'Class not found'}), 404
        
        # Store previous class_id before updating
        previous_class_id = student.class_id
        
        # Update student's class
        student.class_id = class_obj.id
        db.session.commit()
        
        # If student has face encoding completed, transfer embeddings from previous class to new class
        if student.face_encoding_complete:
            try:
                # Path to embeddings directory
                embeddings_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'embeddings')
                
                # Get all embedding files
                embedding_files = [f for f in os.listdir(embeddings_dir) if f.endswith('_embeddings.pkl')]
                
                # Find embedding for previous class
                student_embedding = None
                for file in embedding_files:
                    filepath = os.path.join(embeddings_dir, file)
                    with open(filepath, 'rb') as f:
                        embeddings_dict = pickle.load(f)
                        # Check if the student ID is in this embedding file
                        if str(student_id) in embeddings_dict:
                            student_embedding = embeddings_dict[str(student_id)]
                            break
                
                # If found, add to new class embeddings
                if student_embedding is not None:
                    # Get teacher_id and class_name for the new class
                    teacher_id = str(class_obj.teacher_id)
                    class_name = class_obj.name
                    
                    # Load or create embeddings dict for the new class
                    new_class_file = f"{teacher_id}_{class_name}_embeddings.pkl"
                    new_class_path = os.path.join(embeddings_dir, new_class_file)
                    
                    new_embeddings_dict = {}
                    if os.path.exists(new_class_path):
                        with open(new_class_path, 'rb') as f:
                            new_embeddings_dict = pickle.load(f)
                    
                    # Add student embedding to new class
                    new_embeddings_dict[str(student_id)] = student_embedding
                    
                    # Save updated embeddings
                    with open(new_class_path, 'wb') as f:
                        pickle.dump(new_embeddings_dict, f)
            except Exception as e:
                # Log error but don't prevent class joining
                print(f"Error transferring face embeddings: {str(e)}")
        
        return jsonify({
            'success': True, 
            'message': 'Successfully joined class',
            'class_id': class_obj.id,
            'class_name': class_obj.name
        }), 200
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Upload student face images
@student_api.route('/upload_faces', methods=['POST'])
def upload_faces():
    try:
        student_id = request.form.get('student_id')
        
        if not student_id:
            return jsonify({'success': False, 'message': 'Missing student ID'}), 400
        
        # Check if student exists
        student = Student.query.get(student_id)
        if not student:
            return jsonify({'success': False, 'message': 'Student not found'}), 404
        
        # Check if files are included in the request
        if 'images' not in request.files:
            return jsonify({'success': False, 'message': 'No files uploaded'}), 400
        
        files = request.files.getlist('images')
        if not files or files[0].filename == '':
            return jsonify({'success': False, 'message': 'No files selected'}), 400
        
        # Save images and create database records
        saved_files = []
        for file in files:
            if file:
                filename = save_student_image(file, student_id, student.class_id)
                if filename:
                    # Save file info to database
                    photo = StudentPhoto(filename=filename, student_id=student_id)
                    db.session.add(photo)
                    saved_files.append(filename)
        
        # Only commit if we have saved files
        if saved_files:
            db.session.commit()
            
            # Generate face embeddings for the student
            try:
                face_embedder.generate_embeddings_for_student(student_id, student.class_id)
                student.face_encoding_complete = True
                db.session.commit()
            except Exception as emb_error:
                # If embedding generation fails, still save the images but report the error
                return jsonify({
                    'success': True,
                    'message': 'Images uploaded but face encoding failed',
                    'error': str(emb_error),
                    'files_saved': saved_files
                }), 200
            
            return jsonify({
                'success': True,
                'message': 'Images uploaded and face encoding completed',
                'files_saved': saved_files
            }), 200
        else:
            return jsonify({'success': False, 'message': 'No files could be saved'}), 400
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Submit attendance via face recognition
@student_api.route('/submit_attendance', methods=['POST'])
def submit_attendance():
    try:
        student_id = request.form.get('student_id')
        class_id = request.form.get('class_id')
        
        if not student_id or not class_id:
            return jsonify({'success': False, 'message': 'Missing required fields'}), 400
        
        # Check if student and class exist
        student = Student.query.get(student_id)
        class_obj = Class.query.get(class_id)
        if not student or not class_obj:
            return jsonify({'success': False, 'message': 'Student or class not found'}), 404
        
        # Check if the student belongs to the specified class
        if student.class_id != int(class_id):
            return jsonify({'success': False, 'message': 'Student is not in this class'}), 403
        
        # Check if file is included
        if 'image' not in request.files:
            return jsonify({'success': False, 'message': 'No image uploaded'}), 400
        
        file = request.files['image']
        if not file or file.filename == '':
            return jsonify({'success': False, 'message': 'No image selected'}), 400
        
        # Save the image temporarily
        temp_dir = os.path.join('static', 'uploads', 'temp')
        os.makedirs(temp_dir, exist_ok=True)
        temp_filename = f"attendance_{student_id}_{datetime.now().timestamp()}.jpg"
        temp_path = os.path.join(temp_dir, temp_filename)
        file.save(temp_path)
        
        # Verify the face
        try:
            is_match = face_embedder.verify_student_face(temp_path, student_id, class_id)
            
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                
            if not is_match:
                return jsonify({'success': False, 'message': 'Face verification failed'}), 401
                
            # Check if attendance already exists for today
            today = date.today()
            current_time = datetime.now(timezone.utc)  # Use UTC time for consistent timestamps
            existing_attendance = Attendance.query.filter_by(
                student_id=student_id, 
                class_id=class_id,
                date=today
            ).first()
            
            if existing_attendance:
                existing_attendance.status = True
                existing_attendance.timestamp = current_time  # Update with UTC time
                db.session.commit()
                
                # Display attendance update in terminal
                local_time = current_time.replace(tzinfo=timezone.utc).astimezone()
                formatted_time = local_time.strftime("%Y-%m-%d %H:%M:%S")
                print(f"\n[ATTENDANCE UPDATED] {formatted_time} - Student: {student.name} (ID: {student_id}) - Class: {class_obj.name}\n")
                
                return jsonify({
                    'success': True,
                    'message': 'Attendance updated successfully',
                    'date': today.isoformat(),
                    'timestamp': current_time.isoformat()
                }), 200
            else:
                # Create new attendance record
                new_attendance = Attendance(
                    student_id=student_id,
                    class_id=class_id,
                    date=today,
                    status=True,
                    timestamp=current_time  # Store UTC time
                )
                db.session.add(new_attendance)
                db.session.commit()
                
                # Display attendance marking in terminal
                local_time = current_time.replace(tzinfo=timezone.utc).astimezone()
                formatted_time = local_time.strftime("%Y-%m-%d %H:%M:%S")
                print(f"\n[ATTENDANCE MARKED] {formatted_time} - Student: {student.name} (ID: {student_id}) - Class: {class_obj.name}\n")
                
                return jsonify({
                    'success': True,
                    'message': 'Attendance recorded successfully',
                    'date': today.isoformat(),
                    'timestamp': current_time.isoformat()
                }), 201
                
        except Exception as verif_error:
            # Clean up temporary file if it exists
            if os.path.exists(temp_path):
                os.remove(temp_path)
            return jsonify({'success': False, 'message': f'Face verification error: {str(verif_error)}'}), 500
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Get attendance history for a student
@student_api.route('/attendance_history/<student_id>', methods=['GET'])
def attendance_history(student_id):
    try:
        # Check if student exists
        student = Student.query.get(student_id)
        if not student:
            return jsonify({'success': False, 'message': 'Student not found'}), 404
        
        # Get all attendance records for the student
        attendances = Attendance.query.filter_by(student_id=student_id).order_by(Attendance.date.desc()).all()
        
        # Format the attendance records
        attendance_list = []
        for attendance in attendances:
            attendance_list.append({
                'id': attendance.id,
                'date': attendance.date.isoformat(),
                'status': 'Present' if attendance.status else 'Absent',
                'timestamp': attendance.timestamp.isoformat() if attendance.timestamp else None,
                'class_name': attendance.class_ref.name
            })
        
        return jsonify({
            'success': True,
            'student_id': student_id,
            'student_name': student.name,
            'attendance': attendance_list
        }), 200
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# Get student profile
@student_api.route('/profile/<student_id>', methods=['GET'])
def get_profile(student_id):
    try:
        # Check if student exists
        student = Student.query.get(student_id)
        if not student:
            return jsonify({'success': False, 'message': 'Student not found'}), 404
        
        # Get student details
        return jsonify({
            'success': True,
            'student_id': student.id,
            'name': student.name,
            'email': student.email,
            'class_id': student.class_id,
            'class_name': student.class_ref.name,
            'face_encoding_complete': student.face_encoding_complete,
            'created_at': student.created_at.isoformat()
        }), 200
    
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500