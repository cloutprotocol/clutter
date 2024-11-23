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
        self.root.title("clutter")
        
        # Smaller window size
        window_width = 700
        window_height = 500
        
        # Center window but offset to left
        screen_width = root.winfo_screenwidth()
        screen_height = root.winfo_screenheight()
        x = (screen_width - window_width) // 2 - 100  # Offset 100 pixels to left
        y = (screen_height - window_height) // 2
        
        # Set window geometry with new size and position
        self.root.geometry(f"{window_width}x{window_height}+{x}+{y}")
        
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
        self.create_extension_analyzer_tab()
        self.create_size_analyzer_tab()
        self.create_settings_tab()
        
        # Initialize counters
        self.files_processed = 0
        self.total_size_processed = 0
        
        # Create status bar with terminal styling
        self.status_bar = ttk.Label(
            root, 
            text="🐰 ready", 
            padding=(5, 2, 5, 6),  # Reduced bottom padding from 8 to 6
            font=('Menlo', 11),  # Terminal font, smaller size (fallback to Monaco or Courier)
            background="#2b2b2b",  # Match app dark theme
            foreground="#999999"  # Light gray text
        )
        self.status_bar.pack(fill="x", side="bottom", pady=(0, 3))  # Reduced from 5 to 3

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
        
        # Debug text area setup with darker theme
        self.debug_text = ScrolledText(
            organizer_frame, 
            height=8,
            padx=8,
            pady=8,
            wrap='word',
            borderwidth=0,
            highlightthickness=0,
            bg='#1e1e1e',
            fg='#999999',
            state='disabled',  # Make read-only
            cursor=''  # Hide cursor
        )
        
        # Configure tag for text color
        self.debug_text.tag_configure("default", foreground="#999999")
        
        # Configure scrollbar for darker theme
        self.debug_text.vbar.configure(
            width=8,
            borderwidth=0,
            elementborderwidth=0,
            troughcolor="#1e1e1e",
            background="#2d2d2d",
            activebackground="#3d3d3d"
        )
        
        def hide_scrollbar(*args):
            if self.debug_text.yview() == (0.0, 1.0):
                self.debug_text.vbar.pack_forget()
            else:
                self.debug_text.vbar.pack(side='right', fill='y')
        
        self.debug_text.vbar.pack_forget()
        self.debug_text.bind('<<Modified>>', hide_scrollbar)
        self.debug_text.pack(fill='x', padx=20, pady=5)
        
        # Drop zone with slightly lighter theme
        self.drop_frame = ttk.Frame(organizer_frame)
        self.drop_frame.pack(pady=20, padx=20, expand=True, fill="both")
        
        # Create inner frame for visual feedback
        self.inner_drop_frame = tk.Frame(
            self.drop_frame,
            bg='#2b2b2b',  # Lighter background
            highlightthickness=2,
            highlightbackground='#333333'
        )
        self.inner_drop_frame.pack(expand=True, fill="both", padx=1, pady=1)
        
        # Instructions with matching theme
        instructions = "Drag and drop files or folders here"
        label = tk.Label(
            self.inner_drop_frame,
            text=instructions,
            font=('Arial', 12),
            fg='#999999',
            bg='#2b2b2b'   # Match frame background
        )
        label.pack(expand=True)
        
        # Progress bar
        self.progress = ttk.Progressbar(organizer_frame, mode='determinate')
        self.progress.pack(fill='x', padx=20, pady=(10, 12))  # Reduced from 15 to 12
        
        # Stats labels
        stats_frame = ttk.Frame(organizer_frame)
        stats_frame.pack(fill='x', padx=20, pady=(0, 8))  # Reduced from 10 to 8
        
        self.files_label = ttk.Label(stats_frame, text="Files processed: 0")
        self.files_label.pack(side='left', padx=5)
        
        self.size_label = ttk.Label(stats_frame, text="Total size: 0 MB")
        self.size_label.pack(side='right', padx=5)
        
        # Configure drop zone for DND with visual feedback
        self.drop_frame.drop_target_register(DND_FILES)
        self.drop_frame.dnd_bind('<<Drop>>', self.on_drop)
        
        # Add drag-over effect with brighter blue
        def on_drag_enter(event):
            self.inner_drop_frame.config(
                highlightbackground='#2196F3',  # Bright blue highlight
                bg='#1565C0'  # Darker blue background
            )
            label.config(bg='#1565C0', fg='white')
        
        def on_drag_leave(event):
            self.inner_drop_frame.config(
                highlightbackground='#333333',
                bg='#1e1e1e'
            )
            label.config(bg='#1e1e1e', fg='#999999')
        
        self.drop_frame.dnd_bind('<<DragEnter>>', on_drag_enter)
        self.drop_frame.dnd_bind('<<DragLeave>>', on_drag_leave)

    def create_settings_tab(self):
        """Create settings configuration tab"""
        settings_frame = ttk.Frame(self.notebook)
        
        # Use gear/cog symbol for settings tab
        self.notebook.add(settings_frame, text="⚙️")
        
        # Base directory setting
        dir_frame = ttk.Frame(settings_frame)
        dir_frame.pack(fill='x', padx=10, pady=5)
        
        ttk.Label(dir_frame, text="Output Directory:").pack(side='left', padx=5)
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
        dup_frame.pack(fill='x', padx=10, pady=15)
        
        ttk.Label(dup_frame, text="When file already exists:").pack(side='left', padx=5)
        self.dup_var = tk.StringVar(value=self.config["duplicate_handling"])
        ttk.Radiobutton(
            dup_frame,
            text="Auto-rename",
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
        
        # Save button
        ttk.Button(
            settings_frame,
            text="Save Settings",
            command=self.save_settings
        ).pack(pady=20)

    def create_extension_analyzer_tab(self):
        """Create tab for analyzing file extensions"""
        analyzer_frame = ttk.Frame(self.notebook)
        self.notebook.add(analyzer_frame, text="Extension Analyzer")
        
        # Add text area for results with dark theme
        self.extension_text = ScrolledText(
            analyzer_frame, 
            height=20,
            padx=8,
            pady=8,
            wrap='word',
            borderwidth=0,
            highlightthickness=0,
            bg='#1e1e1e',
            fg='#999999',
            state='disabled',  # Make read-only
            cursor=''  # Hide cursor
        )
        
        # Configure scrollbar for darker theme
        self.extension_text.vbar.configure(
            width=8,
            borderwidth=0,
            elementborderwidth=0,
            troughcolor="#1e1e1e",
            background="#2d2d2d",
            activebackground="#3d3d3d"
        )
        
        # Add auto-hide scrollbar
        def hide_extension_scrollbar(*args):
            if self.extension_text.yview() == (0.0, 1.0):
                self.extension_text.vbar.pack_forget()
            else:
                self.extension_text.vbar.pack(side='right', fill='y')
        
        self.extension_text.vbar.pack_forget()  # Initially hide scrollbar
        self.extension_text.bind('<<Modified>>', hide_extension_scrollbar)
        self.extension_text.pack(fill='both', expand=True, padx=20, pady=5)
        
        # Drop zone with dark theme
        self.analyzer_drop_frame = ttk.Frame(analyzer_frame)
        self.analyzer_drop_frame.pack(pady=10, padx=20, fill='x')
        
        # Create inner frame for visual feedback
        self.inner_analyzer_frame = tk.Frame(
            self.analyzer_drop_frame,
            bg='#2b2b2b',
            highlightthickness=2,
            highlightbackground='#333333'
        )
        self.inner_analyzer_frame.pack(expand=True, fill="both", padx=1, pady=1)
        
        # Instructions with matching theme
        analyzer_label = tk.Label(
            self.inner_analyzer_frame,
            text="Drag files here to analyze their extensions",
            font=('Arial', 12),
            fg='#999999',
            bg='#2b2b2b'
        )
        analyzer_label.pack(expand=True, pady=20)
        
        # Configure drop zone
        self.analyzer_drop_frame.drop_target_register(DND_FILES)
        self.analyzer_drop_frame.dnd_bind('<<Drop>>', self.analyze_extensions)
        
        # Add drag-over effect
        def on_analyzer_enter(event):
            self.inner_analyzer_frame.config(
                highlightbackground='#2196F3',
                bg='#1565C0'
            )
            analyzer_label.config(bg='#1565C0', fg='white')
        
        def on_analyzer_leave(event):
            self.inner_analyzer_frame.config(
                highlightbackground='#333333',
                bg='#2b2b2b'
            )
            analyzer_label.config(bg='#2b2b2b', fg='#999999')
        
        self.analyzer_drop_frame.dnd_bind('<<DragEnter>>', on_analyzer_enter)
        self.analyzer_drop_frame.dnd_bind('<<DragLeave>>', on_analyzer_leave)

    def create_size_analyzer_tab(self):
        """Create tab for analyzing folder sizes"""
        analyzer_frame = ttk.Frame(self.notebook)
        self.notebook.add(analyzer_frame, text="Size Analyzer")
        
        # Add text area for results with dark theme
        self.size_text = ScrolledText(
            analyzer_frame, 
            height=20,
            padx=8,
            pady=8,
            wrap='word',
            borderwidth=0,
            highlightthickness=0,
            bg='#1e1e1e',
            fg='#999999',
            state='disabled',  # Make read-only
            cursor=''  # Hide cursor
        )
        
        # Configure scrollbar for darker theme
        self.size_text.vbar.configure(
            width=8,
            borderwidth=0,
            elementborderwidth=0,
            troughcolor="#1e1e1e",
            background="#2d2d2d",
            activebackground="#3d3d3d"
        )
        
        # Add auto-hide scrollbar
        def hide_size_scrollbar(*args):
            if self.size_text.yview() == (0.0, 1.0):
                self.size_text.vbar.pack_forget()
            else:
                self.size_text.vbar.pack(side='right', fill='y')
        
        self.size_text.vbar.pack_forget()  # Initially hide scrollbar
        self.size_text.bind('<<Modified>>', hide_size_scrollbar)
        self.size_text.pack(fill='both', expand=True, padx=20, pady=5)
        
        # Drop zone with dark theme
        self.size_drop_frame = ttk.Frame(analyzer_frame)
        self.size_drop_frame.pack(pady=10, padx=20, fill='x')
        
        # Create inner frame for visual feedback
        self.inner_size_frame = tk.Frame(
            self.size_drop_frame,
            bg='#2b2b2b',
            highlightthickness=2,
            highlightbackground='#333333'
        )
        self.inner_size_frame.pack(expand=True, fill="both", padx=1, pady=1)
        
        # Instructions with matching theme
        size_label = tk.Label(
            self.inner_size_frame,
            text="Drag folders here to analyze their sizes",
            font=('Arial', 12),
            fg='#999999',
            bg='#2b2b2b'
        )
        size_label.pack(expand=True, pady=20)
        
        # Configure drop zone
        self.size_drop_frame.drop_target_register(DND_FILES)
        self.size_drop_frame.dnd_bind('<<Drop>>', self.analyze_sizes)
        
        # Add drag-over effect
        def on_size_enter(event):
            self.inner_size_frame.config(
                highlightbackground='#2196F3',
                bg='#1565C0'
            )
            size_label.config(bg='#1565C0', fg='white')
        
        def on_size_leave(event):
            self.inner_size_frame.config(
                highlightbackground='#333333',
                bg='#2b2b2b'
            )
            size_label.config(bg='#2b2b2b', fg='#999999')
        
        self.size_drop_frame.dnd_bind('<<DragEnter>>', on_size_enter)
        self.size_drop_frame.dnd_bind('<<DragLeave>>', on_size_leave)

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
                category = None
                
                # Check if file is a screenshot
                screenshot_patterns = ['screen shot', 'screenshot', 'screen-shot', 'screen_shot']
                is_screenshot = extension in ['.png', '.jpg', '.jpeg'] and any(pattern in file_path.name.lower() for pattern in screenshot_patterns)
                
                if is_screenshot:
                    category = "Screenshots"
                # Special cases
                elif extension == '.dmg':
                    category = "Applications"
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
        self.save_config()
        self.base_dir = Path(self.config["base_dir"])
        self.base_dir.mkdir(exist_ok=True)
        self.status_bar.config(text="Settings saved successfully")

    def update_status(self, message):
        """Update status bar message and debug window"""
        print(message)
        self.status_bar.config(text=f"🐰 {message}")  # Add rabbit to all status messages
        self.debug_text.config(state='normal')
        self.debug_text.insert('end', f"{message}\n", "default")
        self.debug_text.see('end')
        self.debug_text.config(state='disabled')
        self.debug_text.edit_modified(True)
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
        self.extension_text.config(state='normal')  # Enable for writing
        self.extension_text.delete(1.0, tk.END)
        self.extension_text.insert(tk.END, report)
        self.extension_text.config(state='disabled')  # Make read-only again
        self.extension_text.see('1.0')  # Scroll to top

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
        self.size_text.config(state='normal')  # Enable for writing
        self.size_text.delete(1.0, tk.END)
        self.size_text.insert(tk.END, report)
        self.size_text.config(state='disabled')  # Make read-only again
        self.size_text.see('1.0')  # Scroll to top

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