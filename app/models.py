from app import db, login_manager
from flask_login import UserMixin
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime
import secrets

@login_manager.user_loader
def load_user(user_id):
    # Try to load a teacher first
    user = Teacher.query.get(int(user_id))
    if user:
        return user
    # If no teacher found, try to load a student
    return Student.query.get(int(user_id))

class Teacher(db.Model, UserMixin):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128))
    classes = db.relationship('Class', backref='teacher', lazy=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class Class(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    teacher_id = db.Column(db.Integer, db.ForeignKey('teacher.id'), nullable=False)
    students = db.relationship('Student', backref='class_ref', lazy=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Adding class code for students to join
    class_code = db.Column(db.String(8), unique=True, nullable=False)
    
    @staticmethod
    def generate_class_code():
        return secrets.token_hex(4)  # 8 characters long

class Student(db.Model, UserMixin):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=True)  # Added email
    password_hash = db.Column(db.String(128), nullable=True)  # Added password
    class_id = db.Column(db.Integer, db.ForeignKey('class.id'), nullable=False)
    photos = db.relationship('StudentPhoto', backref='student', lazy=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    face_encoding_complete = db.Column(db.Boolean, default=False)  # Flag to track if face encoding is complete
    
    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
        
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)
    
    @property
    def last_attendance_time(self):
        # Find the most recent attendance record where status is True (Present)
        last_attendance = Attendance.query.filter_by(
            student_id=self.id, 
            status=True
        ).order_by(Attendance.timestamp.desc()).first()
        
        if last_attendance:
            return last_attendance.timestamp
        return None

class StudentPhoto(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(255), nullable=False)
    student_id = db.Column(db.Integer, db.ForeignKey('student.id'), nullable=False)
    uploaded_at = db.Column(db.DateTime, default=datetime.utcnow)

class Attendance(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    student_id = db.Column(db.Integer, db.ForeignKey('student.id'), nullable=False)
    class_id = db.Column(db.Integer, db.ForeignKey('class.id'), nullable=False)
    date = db.Column(db.Date, nullable=False)
    status = db.Column(db.Boolean, default=False)  # True = Present, False = Absent
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)  # Added timestamp
    
    student = db.relationship('Student', backref='attendances')
    class_ref = db.relationship('Class', backref='attendances')