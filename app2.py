import tkinter as tk
from tkinter import ttk, filedialog
from tkinterdnd2 import DND_FILES, TkinterDnD
import os
import shutil
import mimetypes
from pathlib import Path
from datetime import datetime
import json
import sqlite3
import threading
from PIL import Image
import music_tag
import hashlib
from tkinter.scrolledtext import ScrolledText

# At the top of file, after imports
# Add docstring for main class
class FileOrganizerApp:
    """
    GUI application for organizing files by type with drag & drop support.
    Provides file categorization, search, statistics and analysis features.
    """

    def __init__(self, root):
        self.root = root
        self.root.title("Advanced File Organizer")
        self.root.geometry("800x600")
        
        # Initialize database
        self.init_database()
        
        # Load or create config
        self.config_file = Path.home() / ".file_organizer_config.json"
        self.load_config()
        
        # Create main notebook for tabs
        self.notebook = ttk.Notebook(root)
        self.notebook.pack(expand=True, fill="both", padx=5, pady=5)
        
        # Create tabs
        self.create_organizer_tab()
        self.create_search_tab()
        self.create_stats_tab()
        self.create_settings_tab()
        self.create_extension_analyzer_tab()
        self.create_size_analyzer_tab()
        
        # Initialize counters
        self.files_processed = 0
        self.total_size_processed = 0
        
        # Create status bar
        self.status_bar = ttk.Label(root, text="Ready", relief="sunken")
        self.status_bar.pack(fill="x", side="bottom", padx=5, pady=5)

    def init_database(self):
        """Initialize SQLite database for file tracking"""
        db_path = Path.home() / ".file_organizer.db"
        self.conn = sqlite3.connect(str(db_path))
        self.cursor = self.conn.cursor()
        
        # Create tables if they don't exist
        self.cursor.execute("""
            CREATE TABLE IF NOT EXISTS files (
                id INTEGER PRIMARY KEY,
                original_path TEXT,
                new_path TEXT,
                filename TEXT,
                category TEXT,
                subcategory TEXT,
                size INTEGER,
                date_processed TIMESTAMP,
                hash TEXT,
                metadata TEXT
            )
        """)
        self.conn.commit()

    def load_config(self):
        """Load or create configuration file"""
        default_config = {
            "base_dir": str(Path.home() / "OrganizedFiles"),
            "duplicate_handling": "rename",
            "create_date_folders": True,
            "extract_metadata": True,
            "categories": {
                "Applications": [".app", ".vst3", ".dmg"],
                "Logic Projects": [".logicx"],
                "Screenshots": [],
                "Screen Recordings": [],
                "Images": [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".tiff", ".raw", ".webp", ".svg", 
                          ".ico", ".psd", ".ai", ".eps", ".heic", ".ase", ".jpg_medium", ".jpg_large",
                          ".png_small", ".exr", ".hdr", ".jpeg.webp", ".webp"],
                "Documents": [".pdf", ".doc", ".docx", ".txt", ".rtf", ".odt", ".md", ".csv", ".xls", 
                            ".xlsx", ".ppt", ".pptx", ".pages", ".numbers", ".key", ".epub", ".mobi",
                            ".indd", ".strings", ".vcf", ".ans", ".geojson", ".hex"],
                "Audio": [".mp3", ".wav", ".flac", ".m4a", ".aac", ".mid", ".midi", ".ogg", ".wma", 
                         ".aiff", ".opus", ".ac", ".aif", ".srt"],
                "Video": [".mp4", ".mov", ".avi", ".mkv", ".wmv", ".flv", ".webm", ".m4v", ".3gp", 
                         ".mpg", ".mpeg", ".vob", ".ts", ".mpd"],
                "Archives": [".zip", ".rar", ".7z", ".tar", ".gz", ".bz2", ".xz", ".iso",  
                            ".apk", ".torrent", ".pkg", ".msi"],  # Removed .dmg
                "Code": [".py", ".js", ".html", ".css", ".java", ".cpp", ".php", ".rb", ".swift", 
                        ".json", ".xml", ".sql", ".sh", ".bat", ".ps1", ".go", ".rs", ".tsx", ".jsx", 
                        ".vue", ".ts", ".project", ".glsl", ".p8"],
                "Config": [".ini", ".cfg", ".conf", ".plist", ".yaml", ".yml", ".env", ".gitignore", 
                          ".dockerignore", ".cer", ".mobileconfig", ".icns", ".nib", ".car"],
                "3D": [".obj", ".fbx", ".blend", ".blend1", ".stl", ".3ds", ".dae", ".3dm", ".dwg", 
                      ".skp", ".stp", ".mtl", ".gltf", ".glb", ".usdz", ".lwo", ".usdc"],  # Added .usdc
                "Design": [".sketch", ".ai", ".psd", ".indd", ".eps", ".cdr"],
                "Fonts": [".ttf", ".otf", ".woff", ".woff2", ".eot"],
                "ML": [".pth", ".safetensors"],
                "Others": []
            }
        }
        
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                self.config = json.load(f)
        else:
            self.config = default_config
            self.save_config()
        
        # Ensure base directory exists
        self.base_dir = Path(self.config["base_dir"])
        self.base_dir.mkdir(exist_ok=True)

    def save_config(self):
        """Save current configuration to file"""
        with open(self.config_file, 'w') as f:
            json.dump(self.config, f, indent=4)

    def create_organizer_tab(self):
        """Create main organizer tab with drop zone"""
        organizer_frame = ttk.Frame(self.notebook)
        self.notebook.add(organizer_frame, text="Organizer")
        
        # Add debug text area
        self.debug_text = ScrolledText(organizer_frame, height=5)
        self.debug_text.pack(fill='x', padx=20, pady=5)
        
        # Drop zone
        self.drop_frame = ttk.Frame(organizer_frame, borderwidth=2, relief="solid")
        self.drop_frame.pack(pady=20, padx=20, expand=True, fill="both")
        
        # Progress bar
        self.progress = ttk.Progressbar(organizer_frame, mode='determinate')
        self.progress.pack(fill='x', padx=20, pady=10)
        
        # Stats labels
        stats_frame = ttk.Frame(organizer_frame)
        stats_frame.pack(fill='x', padx=20)
        
        self.files_label = ttk.Label(stats_frame, text="Files processed: 0")
        self.files_label.pack(side='left', padx=5)
        
        self.size_label = ttk.Label(stats_frame, text="Total size: 0 MB")
        self.size_label.pack(side='right', padx=5)
        
        # Configure drop zone for DND
        self.drop_frame.drop_target_register(DND_FILES)
        self.drop_frame.dnd_bind('<<Drop>>', self.on_drop)
        
        # Add instructions
        instructions = "Drag and drop files or folders here to organize them"
        label = ttk.Label(self.drop_frame, text=instructions, justify='left', wraplength=400)
        label.pack(expand=True)

    def create_search_tab(self):
        """Create search tab for finding organized files"""
        search_frame = ttk.Frame(self.notebook)
        self.notebook.add(search_frame, text="Search")
        
        # Search controls
        controls_frame = ttk.Frame(search_frame)
        controls_frame.pack(fill='x', padx=10, pady=5)
        
        ttk.Label(controls_frame, text="Search:").pack(side='left', padx=5)
        self.search_entry = ttk.Entry(controls_frame)
        self.search_entry.pack(side='left', fill='x', expand=True, padx=5)
        
        # Search filters
        filter_frame = ttk.Frame(search_frame)
        filter_frame.pack(fill='x', padx=10, pady=5)
        
        ttk.Label(filter_frame, text="Category:").pack(side='left', padx=5)
        self.category_filter = ttk.Combobox(
            filter_frame,
            values=list(self.config["categories"].keys())
        )
        self.category_filter.pack(side='left', padx=5)
        
        ttk.Button(
            filter_frame,
            text="Search",
            command=self.perform_search
        ).pack(side='right', padx=5)
        
        # Results treeview
        self.results_tree = ttk.Treeview(
            search_frame,
            columns=("Path", "Category", "Size", "Date"),
            show="headings"
        )
        
        self.results_tree.heading("Path", text="Path")
        self.results_tree.heading("Category", text="Category")
        self.results_tree.heading("Size", text="Size")
        self.results_tree.heading("Date", text="Date")
        
        # Add scrollbar
        scrollbar = ttk.Scrollbar(
            search_frame,
            orient="vertical",
            command=self.results_tree.yview
        )
        self.results_tree.configure(yscrollcommand=scrollbar.set)
        
        self.results_tree.pack(fill='both', expand=True, padx=10, pady=5)
        scrollbar.pack(side='right', fill='y')

    def create_stats_tab(self):
        """Create statistics tab"""
        stats_frame = ttk.Frame(self.notebook)
        self.notebook.add(stats_frame, text="Statistics")
        
        # Create canvas for charts
        self.stats_canvas = tk.Canvas(stats_frame)
        self.stats_canvas.pack(fill='both', expand=True, padx=10, pady=5)
        
        # Add stats display
        self.stats_text = ScrolledText(stats_frame, height=10)
        self.stats_text.pack(fill='both', expand=True, padx=10, pady=5)
        
        # Update button
        ttk.Button(
            stats_frame,
            text="Update Statistics",
            command=self.update_statistics
        ).pack(pady=5)

    def create_settings_tab(self):
        """Create settings configuration tab"""
        settings_frame = ttk.Frame(self.notebook)
        self.notebook.add(settings_frame, text="Settings")
        
        # Base directory setting
        dir_frame = ttk.Frame(settings_frame)
        dir_frame.pack(fill='x', padx=10, pady=5)
        
        ttk.Label(dir_frame, text="Base Directory:").pack(side='left', padx=5)
        self.dir_entry = ttk.Entry(dir_frame)
        self.dir_entry.insert(0, str(self.base_dir))
        self.dir_entry.pack(side='left', fill='x', expand=True, padx=5)
        
        ttk.Button(
            dir_frame,
            text="Browse",
            command=self.browse_directory
        ).pack(side='right', padx=5)
        
        # Duplicate handling
        dup_frame = ttk.Frame(settings_frame)
        dup_frame.pack(fill='x', padx=10, pady=5)
        
        ttk.Label(dup_frame, text="Duplicate Handling:").pack(side='left', padx=5)
        self.dup_var = tk.StringVar(value=self.config["duplicate_handling"])
        ttk.Radiobutton(
            dup_frame,
            text="Rename",
            variable=self.dup_var,
            value="rename"
        ).pack(side='left', padx=5)
        ttk.Radiobutton(
            dup_frame,
            text="Skip",
            variable=self.dup_var,
            value="skip"
        ).pack(side='left', padx=5)
        ttk.Radiobutton(
            dup_frame,
            text="Replace",
            variable=self.dup_var,
            value="replace"
        ).pack(side='left', padx=5)
        
        # Other options
        options_frame = ttk.Frame(settings_frame)
        options_frame.pack(fill='x', padx=10, pady=5)
        
        self.date_folders_var = tk.BooleanVar(
            value=self.config["create_date_folders"]
        )
        ttk.Checkbutton(
            options_frame,
            text="Create Date Folders",
            variable=self.date_folders_var
        ).pack(anchor='w')
        
        self.metadata_var = tk.BooleanVar(
            value=self.config["extract_metadata"]
        )
        ttk.Checkbutton(
            options_frame,
            text="Extract Metadata",
            variable=self.metadata_var
        ).pack(anchor='w')
        
        # Save button
        ttk.Button(
            settings_frame,
            text="Save Settings",
            command=self.save_settings
        ).pack(pady=10)

    def create_extension_analyzer_tab(self):
        """Create tab for analyzing file extensions"""
        analyzer_frame = ttk.Frame(self.notebook)
        self.notebook.add(analyzer_frame, text="Extension Analyzer")
        
        # Add text area for results
        self.extension_text = ScrolledText(analyzer_frame, height=20)
        self.extension_text.pack(fill='both', expand=True, padx=20, pady=5)
        
        # Drop zone for extension analysis
        self.analyzer_drop_frame = ttk.Frame(analyzer_frame, borderwidth=2, relief="solid")
        self.analyzer_drop_frame.pack(pady=10, padx=20, fill='x')
        
        # Configure drop zone
        self.analyzer_drop_frame.drop_target_register(DND_FILES)
        self.analyzer_drop_frame.dnd_bind('<<Drop>>', self.analyze_extensions)
        
        # Add instructions
        label = ttk.Label(
            self.analyzer_drop_frame,
            text="Drag files here to analyze their extensions",
            padding=10
        )
        label.pack()

    def create_size_analyzer_tab(self):
        """Create tab for analyzing folder sizes"""
        analyzer_frame = ttk.Frame(self.notebook)
        self.notebook.add(analyzer_frame, text="Size Analyzer")
        
        # Add text area for results
        self.size_text = ScrolledText(analyzer_frame, height=20)
        self.size_text.pack(fill='both', expand=True, padx=20, pady=5)
        
        # Drop zone for size analysis
        self.size_drop_frame = ttk.Frame(analyzer_frame, borderwidth=2, relief="solid")
        self.size_drop_frame.pack(pady=10, padx=20, fill='x')
        
        # Configure drop zone
        self.size_drop_frame.drop_target_register(DND_FILES)
        self.size_drop_frame.dnd_bind('<<Drop>>', self.analyze_sizes)
        
        # Add instructions
        label = ttk.Label(
            self.size_drop_frame,
            text="Drag folders here to analyze their sizes",
            padding=10
        )
        label.pack()

    def extract_metadata(self, file_path):
        """Extract metadata from various file types"""
        metadata = {}
        extension = file_path.suffix.lower()
        
        try:
            if extension in ['.jpg', '.jpeg', '.png', '.gif']:
                with Image.open(file_path) as img:
                    metadata['dimensions'] = img.size
                    metadata['format'] = img.format
                    metadata['mode'] = img.mode
                    if hasattr(img, '_getexif'):
                        exif = img._getexif()
                        if exif:
                            metadata['exif'] = str(exif)
            
            elif extension in ['.mp3', '.m4a', '.flac', '.wav']:
                f = music_tag.load_file(str(file_path))
                metadata['title'] = str(f['title'])
                metadata['artist'] = str(f['artist'])
                metadata['album'] = str(f['album'])
                metadata['year'] = str(f['year'])
            
        except Exception as e:
            metadata['error'] = str(e)
        
        return metadata

    def get_file_hash(self, file_path):
        """Calculate SHA-256 hash of file"""
        hasher = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b''):
                hasher.update(chunk)
        return hasher.hexdigest()

    def organize_file(self, file_path):
        """
        Move a single file to its category folder based on extension.
        Handles path normalization and duplicate files.
        """
        try:
            # Normalize path and verify file exists
            file_path = Path(str(file_path)).resolve()
            if not file_path.exists():
                self.update_status(f"Skipping: {file_path} (not found)")
                return
            
            # Handle bundles (.app, .logicx, .vst3)
            if file_path.is_dir() and file_path.suffix.lower() in ['.app', '.logicx', '.vst3']:
                if file_path.suffix.lower() == '.logicx':
                    category = "Logic Projects"
                elif file_path.suffix.lower() in ['.app', '.vst3']:
                    category = "Applications"
            else:
                # Get category by extension
                extension = file_path.suffix.lower()
                category = None  # Start with no category
                
                # First check for special cases
                if extension == '.dmg':
                    category = "Applications"
                # Then check Images specifically for .webp and .svg
                elif extension in ['.webp', '.svg']:
                    category = "Images"
                else:
                    # Check all categories
                    for cat, exts in self.config["categories"].items():
                        if extension in exts:
                            category = cat
                            break
                
                # If no category found, use Others
                if category is None:
                    category = "Others"
            
            self.update_status(f"Categorizing {file_path.name} as {category}")
            
            # Create destination path
            dest_dir = self.base_dir / category
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest_path = dest_dir / file_path.name
            
            # Handle duplicates
            if dest_path.exists():
                counter = 1
                while dest_path.exists():
                    stem = file_path.stem
                    if stem.endswith(f"_{counter-1}"):
                        stem = stem.rsplit('_', 1)[0]
                    new_name = f"{stem}_{counter}{file_path.suffix}"
                    dest_path = dest_dir / new_name
                    counter += 1
            
            try:
                self.update_status(f"Moving {file_path.name} to {category}")
                shutil.move(str(file_path), str(dest_path))
                self.files_processed += 1
                self.total_size_processed += dest_path.stat().st_size
                self.update_stats_display()
                self.update_status(f"✓ Successfully moved to {category}")
            except Exception as e:
                self.update_status(f"❌ Error moving file: {str(e)}")
            
        except Exception as e:
            self.update_status(f"❌ Error processing {file_path.name}: {str(e)}")

    def update_stats_display(self):
        """Update the statistics display"""
        self.files_label.config(text=f"Files processed: {self.files_processed}")
        size_mb = self.total_size_processed / (1024 * 1024)
        self.size_label.config(text=f"Total size: {size_mb:.2f} MB")

    def perform_search(self):
        """Search for files in the database"""
        search_term = f"%{self.search_entry.get()}%"
        category_filter = self.category_filter.get()
        
        query = """
            SELECT filename, category, size, date_processed, new_path
            FROM files
            WHERE filename LIKE ?
        """
        params = [search_term]
        
        if category_filter:
            query += " AND category = ?"
            params.append(category_filter)
        
        self.cursor.execute(query, params)
        results = self.cursor.fetchall()
        
        # Clear previous results
        for item in self.results_tree.get_children():
            self.results_tree.delete(item)
        
        # Add new results
        for result in results:
            size_mb = result[2] / (1024 * 1024)
            self.results_tree.insert("", "end", values=(
                result[0],
                result[1],
                f"{size_mb:.2f} MB",
                result[3][:19]
            ))

    def update_statistics(self):
        """Update statistics display"""
        self.cursor.execute("""
            SELECT 
                COUNT(*) as total_files,
                SUM(size) as total_size,
                category,
                COUNT(DISTINCT date(date_processed)) as days_active
            FROM files
            GROUP BY category
        """)
        stats = self.cursor.fetchall()
        
        # Clear previous stats
        self.stats_text.delete(1.0, tk.END)
        
        # Add new stats
        self.stats_text.insert(tk.END, "File Organization Statistics\n\n")
        for stat in stats:
            total_files, total_size, category, days = stat
            size_mb = total_size / (1024 * 1024) if total_size else 0
            self.stats_text.insert(tk.END, f"{category}:\n")
            self.stats_text.insert(tk.END, f"  Files: {total_files}\n")
            self.stats_text.insert(tk.END, f"  Total Size: {size_mb:.2f} MB\n")
            self.stats_text.insert(tk.END, f"  Days Active: {days}\n\n")

    def browse_directory(self):
        """Browse for base directory"""
        directory = filedialog.askdirectory(
            initialdir=self.base_dir
        )
        if directory:
            self.dir_entry.delete(0, tk.END)
            self.dir_entry.insert(0, directory)

    def save_settings(self):
        """Save current settings to config"""
        self.config["base_dir"] = self.dir_entry.get()
        self.config["duplicate_handling"] = self.dup_var.get()
        self.config["create_date_folders"] = self.date_folders_var.get()
        self.config["extract_metadata"] = self.metadata_var.get()
        self.save_config()
        self.base_dir = Path(self.config["base_dir"])
        self.base_dir.mkdir(exist_ok=True)
        self.status_bar.config(text="Settings saved successfully")

    def update_status(self, message):
        """Update status bar message and debug window"""
        print(message)  # Add console output for debugging
        self.status_bar.config(text=message)
        self.debug_text.insert('end', f"{message}\n")
        self.debug_text.see('end')
        # Force update the UI
        self.root.update_idletasks()

    def on_drop(self, event):
        """
        Process dropped files/folders from drag & drop event.
        Handles path parsing and runs processing in background thread.
        """
        raw_data = event.data
        
        def process_files():
            paths = []
            
            # Handle different path formats
            if raw_data.startswith('{'):
                # Handle paths in braces
                path_parts = raw_data.strip('{}').split('} {')
                paths.extend(part.strip() for part in path_parts)
            else:
                # Handle space-separated paths
                paths = raw_data.split(' ')
            
            # Clean up paths and process files
            items_to_process = []
            for path in paths:
                try:
                    # Clean and normalize path
                    clean_path = path.strip('"{}').strip()
                    
                    # Convert to Path object and resolve
                    if clean_path.startswith('file://'):
                        clean_path = clean_path[7:]
                    file_path = Path(clean_path).expanduser().resolve()
                    
                    if file_path.exists():
                        items_to_process.append(file_path)
                        self.update_status(f"Added to process: {file_path}")
                    else:
                        # Try URL decoding the path
                        from urllib.parse import unquote
                        decoded_path = unquote(clean_path)
                        file_path = Path(decoded_path).expanduser().resolve()
                        
                        if file_path.exists():
                            items_to_process.append(file_path)
                            self.update_status(f"Added to process: {file_path}")
                        else:
                            self.update_status(f"File not found: {file_path} (raw: {path})")
                except Exception as e:
                    self.update_status(f"Error processing path {path}: {str(e)}")
            
            # Process files
            total_items = len(items_to_process)
            self.update_status(f"Found {total_items} valid items to process")
            
            for i, item_path in enumerate(items_to_process, 1):
                try:
                    self.update_status(f"Processing {i}/{total_items}: {item_path}")
                    if item_path.is_dir():
                        self.organize_folder(item_path)
                    else:
                        self.organize_file(item_path)
                    self.progress['value'] = (i / total_items) * 100
                    
                except Exception as e:
                    self.update_status(f"Error processing {item_path}: {str(e)}")
            
            self.progress['value'] = 0
            self.update_status("Processing complete")
        
        # Run processing in background thread
        thread = threading.Thread(target=process_files)
        thread.start()

    def analyze_extensions(self, event):
        """Analyze file extensions from dropped files"""
        raw_data = event.data
        
        # Parse dropped paths
        paths = raw_data.strip('{}').split('} {')
        paths = [p.strip() for p in paths]
        
        # Dictionary to store extension analysis
        extension_analysis = {}
        processed_files = set()  # Track processed files to avoid duplicates
        
        def analyze_file(path):
            try:
                if path.is_file() and str(path) not in processed_files:
                    processed_files.add(str(path))
                    
                    ext = path.suffix.lower()
                    if not ext:  # Skip files without extensions
                        return
                    
                    if ext not in extension_analysis:
                        extension_analysis[ext] = {
                            'count': 0,
                            'total_size': 0,
                            'examples': [],
                            'mime_type': mimetypes.guess_type(str(path))[0] or 'unknown',
                            'full_paths': []  # Add full paths for debugging
                        }
                    
                    stats = extension_analysis[ext]
                    stats['count'] += 1
                    stats['total_size'] += path.stat().st_size
                    if len(stats['examples']) < 3 and path.name not in stats['examples']:
                        stats['examples'].append(path.name)
                    stats['full_paths'].append(str(path))  # Store full path
                    
                    self.update_status(f"Analyzed: {path.name}")
            except Exception as e:
                self.update_status(f"Error analyzing {path}: {e}")
        
        # Process dropped items
        for path_str in paths:
            try:
                path = Path(path_str).resolve()
                if path.exists():
                    if path.is_file():
                        analyze_file(path)
                    elif path.is_dir():
                        self.update_status(f"Scanning directory: {path}")
                        for item in path.rglob('*'):
                            analyze_file(item)
            except Exception as e:
                self.update_status(f"Error processing {path_str}: {e}")
        
        # Generate report
        report = "Extension Analysis Report\n"
        report += "=" * 50 + "\n\n"
        
        # Show input paths first
        report += "Input Paths:\n"
        for path in paths:
            report += f"- {path}\n"
        report += "\n" + "=" * 50 + "\n\n"
        
        if not extension_analysis:
            report += "No files with extensions found to analyze.\n"
        else:
            for ext, stats in sorted(extension_analysis.items()):
                report += f"Extension: {ext}\n"
                report += f"Count: {stats['count']} files\n"
                report += f"Total Size: {stats['total_size'] / 1024 / 1024:.2f} MB\n"
                report += f"MIME Type: {stats['mime_type']}\n"
                report += "Example files:\n"
                for example in stats['examples']:
                    report += f"  - {example}\n"
                report += "Full paths:\n"
                for path in stats['full_paths']:
                    report += f"  > {path}\n"
                report += "\n"
        
        # Display results
        self.extension_text.delete(1.0, tk.END)
        self.extension_text.insert(tk.END, report)

    def analyze_sizes(self, event):
        """Analyze folder sizes from dropped folders"""
        raw_data = event.data
        
        def get_size(path):
            total = 0
            try:
                if path.is_file():
                    return path.stat().st_size
                for entry in path.rglob('*'):
                    if entry.is_file():
                        total += entry.stat().st_size
            except Exception as e:
                self.update_status(f"Error getting size for {path}: {e}")
            return total
        
        def format_size(size):
            for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
                if size < 1024:
                    return f"{size:.2f} {unit}"
                size /= 1024
            return f"{size:.2f} PB"
        
        # Parse paths
        paths = []
        current_path = ""
        in_braces = False
        
        for char in raw_data:
            if char == '{':
                in_braces = True
            elif char == '}':
                in_braces = False
                if current_path.strip():
                    paths.append(current_path.strip())
                current_path = ""
            elif in_braces:
                current_path += char
            elif char == ' ' and not in_braces:
                if current_path.strip():
                    paths.append(current_path.strip())
                current_path = ""
            else:
                current_path += char
        
        if current_path.strip():
            paths.append(current_path.strip())
        
        # Analyze sizes
        results = []
        for path_str in paths:
            try:
                path = Path(path_str).resolve()
                if path.exists():
                    size = get_size(path)
                    results.append((path, size))
            except Exception as e:
                self.update_status(f"Error processing {path_str}: {e}")
        
        # Sort results by size (largest first)
        results.sort(key=lambda x: x[1], reverse=True)
        
        # Generate report
        report = "Folder Size Analysis\n"
        report += "=" * 50 + "\n\n"
        
        for path, size in results:
            report += f"{path.name}:\n"
            report += f"  Size: {format_size(size)}\n"
            report += f"  Path: {path}\n\n"
        
        # Display results
        self.size_text.delete(1.0, tk.END)
        self.size_text.insert(tk.END, report)

    def organize_folder(self, folder_path):
        """Move entire folder to Folders category"""
        try:
            self.update_status(f"Moving folder: {folder_path.name}")
            dest_dir = self.base_dir / "Folders"
            dest_dir.mkdir(parents=True, exist_ok=True)
            dest_path = dest_dir / folder_path.name
            
            # Handle folder name conflicts
            if dest_path.exists():
                counter = 1
                while dest_path.exists():
                    new_name = f"{folder_path.name}_{counter}"
                    dest_path = dest_dir / new_name
                    counter += 1
            
            self.update_status(f"Moving folder to: {dest_path}")
            shutil.move(str(folder_path), str(dest_path))
            self.files_processed += 1
            self.update_stats_display()
            self.update_status(f"✓ Successfully moved folder to {dest_path}")
            
        except Exception as e:
            self.update_status(f"❌ Error moving folder {folder_path.name}: {str(e)}")

def main():
    root = TkinterDnD.Tk()
    root.title("Advanced File Organizer")
    app = FileOrganizerApp(root)
    root.mainloop()

if __name__ == "__main__":
    main()