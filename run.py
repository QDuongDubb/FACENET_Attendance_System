from app import create_app
import argparse
import os
import subprocess
import sys
import shutil

app = create_app()

def check_facenet_model():
    """
    Check if the David Sandberg FaceNet model exists in the correct location.
    If not, provide instructions on how to download it.
    """
    model_dir = os.path.join(os.path.dirname(__file__), '20180402-114759')
    model_file = os.path.join(model_dir, '20180402-114759.pb')
    
    if not os.path.exists(model_file):
        print("\n" + "="*80)
        print("FaceNet model not found at:", model_file)
        print("\nPlease download the pretrained FaceNet model (20180402-114759) from:")
        print("https://drive.google.com/file/d/1EXPBSXwTaqrSC0OhUdXNmKSh9qJUQ55-/view")
        print("\nExtract the downloaded file and place the '20180402-114759' folder in the root directory of this project.")
        print("="*80 + "\n")
        return False
    
    print("FaceNet model found at:", model_file)
    return True

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Run the Attendance System with Face Recognition')
    parser.add_argument('--host', default='0.0.0.0', help='Host to run the app on')
    parser.add_argument('--port', type=int, default=5001, help='Port to run the app on')
    parser.add_argument('--debug', action='store_true', help='Run in debug mode')
    args = parser.parse_args()
    
    # Check if FaceNet model exists
    if not check_facenet_model():
        sys.exit(1)
    
    # Create necessary directories
    os.makedirs(os.path.join(os.path.dirname(__file__), 'embeddings'), exist_ok=True)
    os.makedirs(os.path.join(os.path.dirname(__file__), 'student_images'), exist_ok=True)
    
    # Run the Flask app
    app.run(host=args.host, port=args.port, debug=args.debug)