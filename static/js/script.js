// General UI enhancements
document.addEventListener('DOMContentLoaded', function() {
    // Enable Bootstrap tooltips
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function(tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });

    // Enable Bootstrap popovers
    const popoverTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="popover"]'));
    popoverTriggerList.map(function(popoverTriggerEl) {
        return new bootstrap.Popover(popoverTriggerEl);
    });

    // Add confirmation for delete actions
    const confirmButtons = document.querySelectorAll('.confirm-action');
    confirmButtons.forEach(button => {
        button.addEventListener('click', function(e) {
            if (!confirm('Are you sure you want to proceed with this action?')) {
                e.preventDefault();
            }
        });
    });

    // Auto-fade out alerts after 5 seconds
    const alerts = document.querySelectorAll('.alert:not(.alert-permanent)');
    alerts.forEach(alert => {
        setTimeout(() => {
            alert.classList.add('fade');
            setTimeout(() => {
                alert.remove();
            }, 500);
        }, 5000);
    });

    // Image preview for file inputs
    const fileInputs = document.querySelectorAll('input[type="file"][accept*="image"]');
    fileInputs.forEach(input => {
        input.addEventListener('change', function(e) {
            const file = e.target.files[0];
            if (file) {
                const reader = new FileReader();
                
                // Find preview element or create one
                let previewId = input.id + '-preview';
                let previewElement = document.getElementById(previewId);
                
                if (!previewElement) {
                    // Create preview element if it doesn't exist
                    previewElement = document.createElement('div');
                    previewElement.id = previewId;
                    previewElement.className = 'mt-2 image-preview';
                    previewElement.style.maxWidth = '150px';
                    previewElement.style.maxHeight = '150px';
                    previewElement.style.overflow = 'hidden';
                    
                    const img = document.createElement('img');
                    img.className = 'img-fluid';
                    previewElement.appendChild(img);
                    
                    // Insert after the input
                    input.parentNode.insertBefore(previewElement, input.nextSibling);
                }
                
                // Display image preview
                reader.onload = function(e) {
                    const img = previewElement.querySelector('img');
                    img.src = e.target.result;
                    previewElement.style.display = 'block';
                };
                
                reader.readAsDataURL(file);
            }
        });
    });
});