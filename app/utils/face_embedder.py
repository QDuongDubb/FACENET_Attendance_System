import tensorflow as tf
import numpy as np
import os
import cv2
import pickle
from mtcnn.mtcnn import MTCNN
import re
from PIL import Image
from io import BytesIO
import glob

class FaceEmbedder:
    def __init__(self, model_path='20180402-114759'):
        self.model_path = model_path
        self.detector = MTCNN()
        self.facenet_graph = None
        self.session = None
        self.embeddings_cache = {}
        self._load_model()

    def _load_model(self):
        """Load the FaceNet model"""
        self.facenet_graph = tf.Graph()
        with self.facenet_graph.as_default():
            # TensorFlow 2.12.0 cần cấu hình session rõ ràng hơn
            config = tf.compat.v1.ConfigProto()
            config.gpu_options.allow_growth = True
            self.session = tf.compat.v1.Session(config=config)
            
            with self.session.as_default():
                # Load the model
                # Fix the path to look in the project root directory instead of the app directory
                model_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 
                                         self.model_path, '20180402-114759.pb')
                if not os.path.exists(model_path):
                    raise FileNotFoundError(f"Model file not found at {model_path}")
                
                with tf.io.gfile.GFile(model_path, 'rb') as f:
                    graph_def = tf.compat.v1.GraphDef()
                    graph_def.ParseFromString(f.read())
                    tf.compat.v1.import_graph_def(graph_def, name='')
                
                # Get input and output tensors
                self.images_placeholder = tf.compat.v1.get_default_graph().get_tensor_by_name("input:0")
                self.embeddings = tf.compat.v1.get_default_graph().get_tensor_by_name("embeddings:0")
                self.phase_train_placeholder = tf.compat.v1.get_default_graph().get_tensor_by_name("phase_train:0")
                print("FaceNet model loaded successfully")

    def detect_faces(self, image):
        """Detect faces in an image using MTCNN"""
        if isinstance(image, str):
            # Load image from file
            image = cv2.imread(image)
            image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        elif isinstance(image, bytes):
            # Load image from bytes
            nparr = np.frombuffer(image, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        elif isinstance(image, np.ndarray) and image.shape[2] == 3 and image.dtype == np.uint8:
            # Convert BGR to RGB if needed
            if len(image.shape) == 3 and image.shape[2] == 3:
                if image[0, 0, 0] > image[0, 0, 2]:  # Simple heuristic to detect BGR
                    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        else:
            raise ValueError("Unsupported image format")
        
        # Detect faces
        faces = self.detector.detect_faces(image)
        return faces, image

    def prewhiten(self, img):
        """
        Prewhiten image exactly as in David Sandberg's FaceNet implementation.
        This implementation uses a standard adjustment to ensure 
        normalization even with low-variance images.
        """
        mean = np.mean(img)
        std = np.std(img)
        # Use standard adjustment to handle low variance
        std_adj = np.maximum(std, 1.0/np.sqrt(img.size))
        # Standardize the image
        whitened_img = np.multiply(np.subtract(img, mean), 1/std_adj)
        return whitened_img
    
    def preprocess_face(self, image, face, target_size=(160, 160)):
        """
        Extract, align and preprocess face for FaceNet embedding.
        Includes cropping, resizing, and prewhitening.
        """
        x, y, width, height = face['box']
        x, y = max(x, 0), max(y, 0)  # Ensure non-negative values
        
        # Extract face with a margin for better alignment
        margin_percent = 0.2  # 20% margin
        margin = int(min(width, height) * margin_percent)
        x_min = max(0, x - margin)
        y_min = max(0, y - margin)
        x_max = min(image.shape[1], x + width + margin)
        y_max = min(image.shape[0], y + height + margin)
        
        face_img = image[y_min:y_max, x_min:x_max]
        
        # Handle facial landmarks for alignment if needed (simplified for now)
        # In a full implementation, we would use the landmarks to align the face
        
        # Resize to target size
        face_img = cv2.resize(face_img, target_size, interpolation=cv2.INTER_CUBIC)
        
        # Convert to float32
        face_img = face_img.astype(np.float32)
        
        # Normalize to [0,1]
        face_img /= 255.0
        
        # Prewhiten using Sandberg's method
        face_img = self.prewhiten(face_img)
        
        return face_img

    def get_embedding(self, face_img):
        """Get face embedding using FaceNet"""
        with self.facenet_graph.as_default():
            with self.session.as_default():
                # Add batch dimension
                face_img = np.expand_dims(face_img, axis=0)
                
                # Get embedding
                feed_dict = {self.images_placeholder: face_img, self.phase_train_placeholder: False}
                embedding = self.session.run(self.embeddings, feed_dict=feed_dict)
                
                # Return the flattened embedding
                return embedding[0]

    def compute_average_embedding(self, images):
        """
        Compute average embedding from multiple face images.
        Multiple images improve recognition accuracy.
        """
        embeddings = []
        
        for image in images:
            faces, img = self.detect_faces(image)
            
            if not faces:
                continue
                
            # Use the face with the highest confidence
            face = max(faces, key=lambda x: x['confidence'])
            face_img = self.preprocess_face(img, face)
            embedding = self.get_embedding(face_img)
            embeddings.append(embedding)
            
        if not embeddings:
            return None
            
        # Compute average embedding
        avg_embedding = np.mean(embeddings, axis=0)
        # Normalize the embedding to unit length (important for cosine similarity)
        avg_embedding = avg_embedding / np.linalg.norm(avg_embedding)
        
        return avg_embedding

    def compute_embeddings_for_student(self, images):
        """
        Compute embeddings for a student from multiple images.
        Returns a list of embeddings for each valid face detected.
        """
        embeddings = []
        
        for image in images:
            faces, img = self.detect_faces(image)
            
            if not faces:
                continue
                
            # Get the face with the highest confidence
            face = max(faces, key=lambda x: x['confidence'])
            if face['confidence'] < 0.9:  # Skip low confidence faces
                continue
                
            # Preprocess and get embedding
            face_img = self.preprocess_face(img, face)
            embedding = self.get_embedding(face_img)
            
            # Normalize embedding to unit length
            embedding = embedding / np.linalg.norm(embedding)
            embeddings.append(embedding)
            
        return embeddings

    def save_class_embeddings(self, teacher_id, class_name, embeddings_dict):
        """Save embeddings for a class to a pickle file"""
        embeddings_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'embeddings')
        os.makedirs(embeddings_dir, exist_ok=True)
        
        filename = f"{teacher_id}_{class_name}_embeddings.pkl"
        filepath = os.path.join(embeddings_dir, filename)
        
        with open(filepath, 'wb') as f:
            pickle.dump(embeddings_dict, f)
            
        return filepath

    def load_class_embeddings(self, teacher_id, class_name):
        """Load embeddings for a class from a pickle file"""
        embeddings_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'embeddings')
        filename = f"{teacher_id}_{class_name}_embeddings.pkl"
        filepath = os.path.join(embeddings_dir, filename)
        
        if os.path.exists(filepath):
            with open(filepath, 'rb') as f:
                return pickle.load(f)
        
        return {}

    def compare_faces(self, embedding, embeddings_dict, threshold=0.6):
        """Compare a face embedding with stored embeddings and return the best match"""
        best_match = None
        best_similarity = -1
        
        for student_name, stored_embedding in embeddings_dict.items():
            # Calculate cosine similarity (dot product of normalized embeddings)
            similarity = np.dot(embedding, stored_embedding)
            
            if similarity > threshold and similarity > best_similarity:
                best_similarity = similarity
                best_match = student_name
                
        return best_match, best_similarity

    def process_attendance_image(self, teacher_id, class_name, image):
        """Process an attendance image and return recognized students"""
        # Load class embeddings
        embeddings_dict = self.load_class_embeddings(teacher_id, class_name)
        
        if not embeddings_dict:
            return [], "No embeddings found for this class."
            
        # Detect faces
        faces, img = self.detect_faces(image)
        
        if not faces:
            return [], "No faces detected in the image."
            
        results = []
        
        for i, face in enumerate(faces):
            # Preprocess face
            face_img = self.preprocess_face(img, face)
            
            # Get embedding
            embedding = self.get_embedding(face_img)
            
            # Normalize embedding to unit length for cosine similarity
            embedding = embedding / np.linalg.norm(embedding)
            
            # Compare with stored embeddings
            student_name, similarity = self.compare_faces(embedding, embeddings_dict)
            
            # Store result
            results.append({
                'face_index': i,
                'box': face['box'],
                'matched': student_name is not None,
                'student_name': student_name,
                'confidence': float(similarity) if student_name else 0
            })
            
        return results, "Attendance processed successfully."
    
    def verify_student_face(self, image_path, student_id, class_id):
        """
        Verify if the face in the image matches the stored face embeddings of the student.
        
        Args:
            image_path: Path to the image file containing the student's face
            student_id: ID of the student to verify
            class_id: ID of the class the student belongs to
            
        Returns:
            bool: True if face matches, False otherwise
        """
        try:
            # Load the image
            if not os.path.exists(image_path):
                raise FileNotFoundError(f"Image file not found at {image_path}")
            
            # Detect faces in the image
            faces, img = self.detect_faces(image_path)
            
            if not faces:
                raise ValueError("No faces detected in the image")
            
            # Get the face with highest confidence
            face = max(faces, key=lambda x: x['confidence'])
            
            if face['confidence'] < 0.9:
                raise ValueError(f"Face detection confidence too low: {face['confidence']}")
            
            # Preprocess and get embedding for the submitted face
            face_img = self.preprocess_face(img, face)
            submission_embedding = self.get_embedding(face_img)
            
            # Normalize embedding to unit length for cosine similarity
            submission_embedding = submission_embedding / np.linalg.norm(submission_embedding)
            
            # Load embeddings for the class
            embeddings_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'embeddings')
            # Find the appropriate embedding file for the class
            embedding_files = [f for f in os.listdir(embeddings_dir) if f.endswith('_embeddings.pkl')]
            
            student_embedding = None
            for file in embedding_files:
                filepath = os.path.join(embeddings_dir, file)
                with open(filepath, 'rb') as f:
                    embeddings_dict = pickle.load(f)
                    # Check if the student ID is in this embedding file
                    if str(student_id) in embeddings_dict:
                        student_embedding = embeddings_dict[str(student_id)]
                        break
            
            if student_embedding is None:
                raise ValueError(f"No face embeddings found for student ID: {student_id}")
            
            # Calculate similarity (cosine similarity between normalized vectors)
            similarity = np.dot(submission_embedding, student_embedding)
            
            # Define a threshold for verification
            threshold = 0.6  # Adjust based on your needs
            
            # Return verification result
            return similarity > threshold
            
        except Exception as e:
            raise Exception(f"Face verification failed: {str(e)}")

    def generate_embeddings_for_student(self, student_id, class_id):
        """
        Generate face embeddings for a student from their uploaded photos.
        Updates the class embeddings file with the student's embeddings.
        
        Args:
            student_id: ID of the student
            class_id: ID of the class the student belongs to
            
        Returns:
            bool: True if embeddings were generated successfully
        """
        try:
            # Get paths to student images
            student_dir = os.path.join(
                os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                'static', 'uploads', 'student_images', str(class_id), str(student_id)
            )
            
            if not os.path.exists(student_dir):
                raise FileNotFoundError(f"No images directory found for student {student_id}")
                
            # Get all image files for the student
            image_files = glob.glob(os.path.join(student_dir, '*.jpg'))
            if not image_files:
                raise ValueError(f"No image files found for student {student_id}")
                
            # Compute embeddings for the student images
            embeddings = self.compute_embeddings_for_student(image_files)
            
            if not embeddings:
                raise ValueError(f"Failed to compute embeddings for student {student_id}")
                
            # Compute the average embedding
            avg_embedding = np.mean(embeddings, axis=0)
            # Normalize the average embedding
            avg_embedding = avg_embedding / np.linalg.norm(avg_embedding)
            
            # Find the class embedding file from any teacher
            embeddings_dir = os.path.join(
                os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 
                'embeddings'
            )
            os.makedirs(embeddings_dir, exist_ok=True)
            
            # Look for appropriate class embedding file
            embedding_files = [f for f in os.listdir(embeddings_dir) if f.endswith('_embeddings.pkl')]
            
            # Check if there's a file for this class
            class_embedding_file = None
            teacher_id = None
            class_name = None
            
            for file in embedding_files:
                # Extract class_id if it's in the file name
                if f"_{class_id}_" in file or file.startswith(f"{class_id}_"):
                    class_embedding_file = file
                    parts = re.match(r"(\d+)_(.+)_embeddings\.pkl", file)
                    if parts:
                        teacher_id = parts.group(1)
                        class_name = parts.group(2)
                    break
            
            # If no file exists for this class yet, we need to create one
            # This requires knowing the teacher_id and class_name
            if not class_embedding_file:
                # Try to infer teacher_id and class_name from other files
                # Assumption: first part of filename is teacher_id
                if embedding_files:
                    parts = re.match(r"(\d+)_.+", embedding_files[0])
                    if parts:
                        teacher_id = parts.group(1)
                        # Use class_id as the class_name if we can't determine it
                        class_name = str(class_id)
                else:
                    # Default values if no other info is available
                    teacher_id = "1"  # Assuming default teacher id
                    class_name = str(class_id)
                
                class_embedding_file = f"{teacher_id}_{class_name}_embeddings.pkl"
            
            # Full path to the embedding file
            filepath = os.path.join(embeddings_dir, class_embedding_file)
            
            # Load existing embeddings or create new dict
            embeddings_dict = {}
            if os.path.exists(filepath):
                with open(filepath, 'rb') as f:
                    embeddings_dict = pickle.load(f)
            
            # Add or update the student's embedding
            embeddings_dict[str(student_id)] = avg_embedding
            
            # Save the updated embeddings
            with open(filepath, 'wb') as f:
                pickle.dump(embeddings_dict, f)
            
            return True
            
        except Exception as e:
            raise Exception(f"Failed to generate embeddings: {str(e)}")