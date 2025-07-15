def compare_faces(self, embedding, embeddings_dict, threshold=0.6):
    """Compare a face embedding with stored embeddings and return the best match"""
    best_match = None
    best_similarity = -1
    
    for student_name, stored_embedding in embeddings_dict.items():
        # Calculate cosine similarity (dot product of normalized embeddings)
        similarity = np.dot(embedding, stored_embedding)  # Tính độ tương đồng cosine
        
        if similarity > threshold and similarity > best_similarity:
            best_similarity = similarity
            best_match = student_name
            
    return best_match, best_similarity