import Foundation

class FileSystemManager {
    static let shared = FileSystemManager()
    
    private let baseDir: URL
    private let categories: [String: [String]] = [
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
                    ".apk", ".torrent", ".pkg", ".msi"],
        "Code": [".py", ".js", ".html", ".css", ".java", ".cpp", ".php", ".rb", ".swift", 
                ".json", ".xml", ".sql", ".sh", ".bat", ".ps1", ".go", ".rs", ".tsx", ".jsx", 
                ".vue", ".ts", ".project", ".glsl", ".p8"],
        "Config": [".ini", ".cfg", ".conf", ".plist", ".yaml", ".yml", ".env", ".gitignore", 
                  ".dockerignore", ".cer", ".mobileconfig", ".icns", ".nib", ".car"],
        "3D": [".obj", ".fbx", ".blend", ".blend1", ".stl", ".3ds", ".dae", ".3dm", ".dwg", 
              ".skp", ".stp", ".mtl", ".gltf", ".glb", ".usdz", ".lwo", ".usdc"],
        "Design": [".sketch", ".ai", ".psd", ".indd", ".eps", ".cdr"],
        "Fonts": [".ttf", ".otf", ".woff", ".woff2", ".eot"],
        "ML": [".pth", ".safetensors"],
        "Others": []
    ]
    
    private init() {
        baseDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OrganizedFiles")
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
    }
    
    func organizeFile(at url: URL) throws {
        let ext = url.pathExtension.lowercased()
        var category = "Others"
        
        // Check if file is a screenshot
        if ["png", "jpg", "jpeg"].contains(ext) {
            let filename = url.lastPathComponent.lowercased()
            if filename.contains("screen shot") || filename.contains("screenshot") {
                category = "Screenshots"
            }
        }
        
        // Find category for extension
        if category == "Others" {
            for (cat, extensions) in categories {
                if extensions.contains("." + ext) {
                    category = cat
                    break
                }
            }
        }
        
        let destDir = baseDir.appendingPathComponent(category)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        
        var destURL = destDir.appendingPathComponent(url.lastPathComponent)
        
        // Handle duplicates
        if FileManager.default.fileExists(atPath: destURL.path) {
            var counter = 1
            let filename = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            
            while FileManager.default.fileExists(atPath: destURL.path) {
                destURL = destDir.appendingPathComponent("\(filename)_\(counter).\(ext)")
                counter += 1
            }
        }
        
        try FileManager.default.moveItem(at: url, to: destURL)
    }
    
    func scanDirectory(at path: String) -> [String] {
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(atPath: path)
            return files
        } catch {
            print("Error scanning directory: \(error)")
            return []
        }
    }
} 