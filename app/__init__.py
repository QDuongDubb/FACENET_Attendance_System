from flask import Flask, request
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from flask_migrate import Migrate
from flask_cors import CORS
import os
import logging
from datetime import datetime, timedelta

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger('attendance-app')

# Initialize extensions
db = SQLAlchemy()
login_manager = LoginManager()
migrate = Migrate()

def create_app():
    app = Flask(__name__, 
                template_folder='../templates',
                static_folder='../static')
    
    # Configure app
    app.config['SECRET_KEY'] = 'your-secret-key-goes-here'
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///../attendance.db'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['UPLOAD_FOLDER'] = os.path.join(app.static_folder, 'uploads/student_images')
    
    # Enable CORS for all routes
    CORS(app, resources={r"/api/*": {"origins": "*"}})
    
    # Add custom filter for adjusting time display with +7 hours
    @app.template_filter('adjust_time')
    def adjust_time_filter(value):
        if not value or value == 'Never':
            return 'Never'
        if isinstance(value, datetime):
            adjusted_time = value + timedelta(hours=7)
            return adjusted_time.strftime('%Y-%m-%d %H:%M:%S')
        return value
    
    # Request logger middleware
    @app.before_request
    def log_request_info():
        # Get client info
        user_agent = request.headers.get('User-Agent', 'Unknown')
        ip = request.remote_addr
        endpoint = request.endpoint
        path = request.path
        method = request.method
        
        # Determine if this is a mobile request
        is_mobile = any(keyword in user_agent.lower() for keyword in ['android', 'iphone', 'mobile', 'flutter'])
        
        # Create a descriptive message
        device_type = "MOBILE DEVICE" if is_mobile else "Desktop/Browser"
        
        # Log the connection
        logger.info(f"Connection from {device_type} - IP: {ip} - Path: {method} {path}")
        
        # Log additional details at debug level
        logger.debug(f"User-Agent: {user_agent}")
    
    # Initialize extensions with app
    db.init_app(app)
    login_manager.init_app(app)
    migrate.init_app(app, db)
    login_manager.login_view = 'auth.login'
    
    # Import and register blueprints
    from app.routes.auth import auth as auth_blueprint
    from app.routes.main import main as main_blueprint
    from app.routes.classes import classes as classes_blueprint
    from app.routes.api import api as api_blueprint
    from app.routes.student_api import student_api as student_api_blueprint
    
    app.register_blueprint(auth_blueprint)
    app.register_blueprint(main_blueprint)
    app.register_blueprint(classes_blueprint)
    app.register_blueprint(api_blueprint)
    app.register_blueprint(student_api_blueprint, url_prefix='/api/student')
    
    # Ensure upload directory exists
    os.makedirs(app.config['UPLOAD_FOLDER'], exist_ok=True)
    
    # Create database tables
    with app.app_context():
        db.create_all()
    
    # Add template context processor for current year
    @app.context_processor
    def inject_now():
        return {'now': datetime.now()}
    
    return app