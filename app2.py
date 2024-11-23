def organize_file(self, file_path):
    try:
        # Normalize path and verify file exists
        file_path = Path(str(file_path)).resolve()
        if not file_path.exists():
            self.update_status(f"Skipping: {file_path} (not found)")
            return
        
        # Check for screenshots first
        filename = file_path.name
        filename_lower = filename.lower()
        
        # Debug logging
        self.update_status(f"Checking filename: {filename}")
        self.update_status(f"Starts with 'Screen Shot': {filename.startswith('Screen Shot')}")
        self.update_status(f"Contains ' at ': {' at ' in filename}")
        
        if filename.startswith("Screen Shot") and " at " in filename:
            category = "Screenshots"
            self.update_status(f"Detected Apple screenshot: {file_path.name}")
        elif ("screenshot" in filename_lower or 
              "screen_shot" in filename_lower or
              "screen-shot" in filename_lower or
              "capture" in filename_lower):
            category = "Screenshots"
            self.update_status(f"Detected screenshot: {file_path.name}")
        elif ("screen recording" in filename_lower or 
              "screenrecording" in filename_lower or 
              "screen-recording" in filename_lower):
            category = "Screen Recordings"
        else:
            # Get category by extension
            extension = file_path.suffix.lower()
            category = None
            
            if extension == '.dmg':
                category = "Applications"
            elif extension in ['.webp', '.svg']:
                category = "Images"
            else:
                for cat, exts in self.config["categories"].items():
                    if extension in exts:
                        category = cat
                        break
            
            if category is None:
                category = "Others"
        
        # Debug logging for chosen category
        self.update_status(f"Selected category: {category}")
        
        # Continue with moving the file...
    except Exception as e:
        self.update_status(f"Error organizing file: {file_path} - {e}")