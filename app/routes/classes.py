from flask import Blueprint, render_template, redirect, url_for, flash, request, current_app
from flask_login import login_required, current_user
from app.models import Class, Student, StudentPhoto
from app.utils.face_embedder import FaceEmbedder
from app import db
from werkzeug.utils import secure_filename
import os
from flask_wtf import FlaskForm
from wtforms import StringField, SubmitField
from wtforms.validators import DataRequired
import uuid
import traceback
import secrets
import string

classes = Blueprint('classes', __name__)

# Initialize face embedder
face_embedder = None

def get_face_embedder():
    global face_embedder
    if face_embedder is None:
        try:
            face_embedder = FaceEmbedder()
            print("FaceEmbedder initialized successfully")
        except Exception as e:
            print(f"Error initializing face embedder: {e}")
            traceback.print_exc()
    return face_embedder

class ClassForm(FlaskForm):
    name = StringField('Class Name', validators=[DataRequired()])
    submit = SubmitField('Create Class')

# Generate a more user-friendly class code
def generate_class_code(name):
    prefix = ''.join(c.upper() for c in name if c.isalpha())[:4]
    if len(prefix) < 2:
        prefix = 'CLS'  # Default if name doesn't have enough letters
    suffix = ''.join(secrets.choice(string.ascii_uppercase + string.digits) for _ in range(4))
    return f"{prefix}-{suffix}"

@classes.route('/classes')
@login_required
def list_classes():
    teacher_classes = Class.query.filter_by(teacher_id=current_user.id).all()
    return render_template('classes/list.html', title='My Classes', classes=teacher_classes)

@classes.route('/classes/create', methods=['GET', 'POST'])
@login_required
def create_class():
    form = ClassForm()
    if form.validate_on_submit():
        # Generate a class code based on name
        class_code = generate_class_code(form.name.data)
        
        new_class = Class(name=form.name.data, teacher_id=current_user.id, class_code=class_code)
        db.session.add(new_class)
        db.session.commit()
        
        flash(f'Class "{form.name.data}" created successfully!', 'success')
        flash(f'Class Code: {class_code} - Share this with your students to join the class.', 'info')
        return redirect(url_for('classes.view_class', class_id=new_class.id))
    
    return render_template('classes/create.html', title='Create Class', form=form)

@classes.route('/classes/<int:class_id>/add-students', methods=['GET', 'POST'])
@login_required
def add_students(class_id):
    class_obj = Class.query.get_or_404(class_id)
    
    # Check if current user is the teacher of this class
    if class_obj.teacher_id != current_user.id:
        flash('You do not have permission to edit this class')
        return redirect(url_for('classes.list_classes'))
    
    num_students = request.args.get('num_students', type=int)
    
    if request.method == 'POST':
        # Get face embedder
        embedder = get_face_embedder()
        if embedder is None:
            flash('Face recognition system is not available. Students will be added without face embeddings.', 'warning')
        
        # Initialize embeddings dictionary for this class
        embeddings_dict = {}
        
        # Process student data from form
        student_names = request.form.getlist('student_name')
        
        for i, name in enumerate(student_names):
            if name.strip():  # Skip empty names
                student = Student(name=name, class_id=class_id)
                db.session.add(student)
                db.session.flush()  # Get student ID before commit
                
                # Create directory for student images
                student_dir = os.path.join(current_app.root_path, '..', 'student_images', 
                                          str(current_user.id), class_obj.name, name)
                os.makedirs(student_dir, exist_ok=True)
                
                # Process student photos and collect them for embedding
                student_images = []
                photo_count = 0
                
                # Allow up to 10 photos per student (increased from 4)
                for j in range(10):  
                    photo_key = f'student_photo_{i}_{j}'
                    if photo_key in request.files:
                        photo_file = request.files[photo_key]
                        if photo_file and photo_file.filename:
                            filename = secure_filename(photo_file.filename)
                            # Generate a unique filename to avoid duplicates
                            unique_filename = f"{uuid.uuid4()}_{filename}"
                            
                            # Save file to student-specific directory
                            photo_path = os.path.join(student_dir, unique_filename)
                            photo_file.save(photo_path)
                            
                            # Create student photo record
                            photo = StudentPhoto(filename=photo_path, student_id=student.id)
                            db.session.add(photo)
                            
                            # Add to images list for embedding
                            student_images.append(photo_path)
                            photo_count += 1
                
                print(f"Added {photo_count} photos for student {name}")
                
                # Create face embedding if we have images and embedder is available
                if embedder and student_images:
                    try:
                        print(f"Computing embedding for student {name} from {len(student_images)} images")
                        # Compute average embedding for student
                        embedding = embedder.compute_average_embedding(student_images)
                        if embedding is not None:
                            embeddings_dict[name] = embedding
                            print(f"Successfully created embedding for {name}")
                        else:
                            print(f"Failed to create embedding for {name}: No valid faces detected in provided images")
                            flash(f"Could not detect face in images for {name}. Please ensure face is clearly visible.", "warning")
                    except Exception as e:
                        print(f"Error creating face embedding for {name}: {str(e)}")
                        traceback.print_exc()
                        flash(f"Could not create face embedding for {name}: {str(e)}", "warning")
        
        # Save embeddings if we have any
        if embedder and embeddings_dict:
            try:
                embeddings_file = embedder.save_class_embeddings(current_user.id, class_obj.name, embeddings_dict)
                flash(f'Face embeddings created and saved to {embeddings_file}', 'success')
                print(f"Saved embeddings for {len(embeddings_dict)} students to {embeddings_file}")
            except Exception as e:
                print(f"Error saving face embeddings: {str(e)}")
                traceback.print_exc()
                flash(f"Error saving face embeddings: {str(e)}", "danger")
        elif embedder and not embeddings_dict:
            flash("No valid face embeddings could be created. Please make sure student photos show clear, front-facing faces.", "danger")
            print("No embeddings were created to save")
        
        db.session.commit()
        flash('Students added successfully!', 'success')
        return redirect(url_for('classes.view_class', class_id=class_id))
    
    return render_template('classes/add_students.html', title='Add Students', 
                          class_obj=class_obj, num_students=num_students)

@classes.route('/classes/<int:class_id>')
@login_required
def view_class(class_id):
    class_obj = Class.query.get_or_404(class_id)
    
    # Check if current user is the teacher of this class
    if class_obj.teacher_id != current_user.id:
        flash('You do not have permission to view this class')
        return redirect(url_for('classes.list_classes'))
    
    students = Student.query.filter_by(class_id=class_id).all()
    
    # Check if face embeddings exist for this class
    embedder = get_face_embedder()
    has_embeddings = False
    if embedder:
        embeddings_dict = embedder.load_class_embeddings(current_user.id, class_obj.name)
        has_embeddings = len(embeddings_dict) > 0
    
    return render_template('classes/view.html', title=class_obj.name, 
                          class_obj=class_obj, students=students, has_embeddings=has_embeddings)

@classes.route('/classes/<int:class_id>/attendance')
@login_required
def take_attendance(class_id):
    class_obj = Class.query.get_or_404(class_id)
    
    # Check if current user is the teacher of this class
    if class_obj.teacher_id != current_user.id:
        flash('You do not have permission to take attendance for this class')
        return redirect(url_for('classes.list_classes'))
    
    students = Student.query.filter_by(class_id=class_id).all()
    
    # Check if face embeddings exist for this class
    embedder = get_face_embedder()
    has_embeddings = False
    if embedder:
        embeddings_dict = embedder.load_class_embeddings(current_user.id, class_obj.name)
        has_embeddings = len(embeddings_dict) > 0
    
    if not has_embeddings:
        flash('No face embeddings found for this class. Students need to be added with photos first.')
    
    return render_template('classes/attendance.html', title=f'Attendance - {class_obj.name}', 
                          class_obj=class_obj, students=students, has_embeddings=has_embeddings)