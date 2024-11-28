import Foundation

public class FileManager: ObservableObject {
    public static let shared = FileManager()
    
    @Published public var baseDir: URL {
        didSet {
            saveSettings()
        }
    }
    
    @Published public var currentDuplicateHandling: String {
        didSet {
            saveSettings()
        }
    }
    
    @Published public var categories: [String: [String]] = [
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
    
    private var customPaths: [String: String] = [:]
    private let settingsURL = Foundation.FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("cr4sh0ut_settings.json")
    
    private init() {
        if let data = try? Data(contentsOf: settingsURL),
           let settings = try? JSONDecoder().decode([String: String].self, from: data) {
            baseDir = URL(fileURLWithPath: settings["baseDir"] ?? "")
            currentDuplicateHandling = settings["duplicateHandling"] ?? "rename"
            if let pathsData = settings["customPaths"]?.data(using: .utf8),
               let paths = try? JSONDecoder().decode([String: String].self, from: pathsData) {
                customPaths = paths
            }
        } else {
            baseDir = Foundation.FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("cr4sh0ut")
            currentDuplicateHandling = "rename"
        }
        
        try? Foundation.FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
    }
    
    public func updateBaseDir(path: String) throws {
        let url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        
        if Foundation.FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                throw NSError(domain: "FileManager", code: 1, 
                            userInfo: [NSLocalizedDescriptionKey: "Selected path is not a directory"])
            }
        } else {
            try Foundation.FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        
        baseDir = url
    }
    
    public func saveDuplicateHandling(_ handling: String) {
        guard ["rename", "skip", "replace"].contains(handling) else { return }
        currentDuplicateHandling = handling
    }
    
    public func updateMapping(category: String, path: String) {
        customPaths[category] = path
        saveSettings()
        objectWillChange.send()
    }
    
    public func getCustomPath(for category: String) -> String? {
        return customPaths[category]
    }
    
    private func saveSettings() {
        var settings: [String: String] = [
            "baseDir": baseDir.path,
            "duplicateHandling": currentDuplicateHandling
        ]
        
        if let pathsData = try? JSONEncoder().encode(customPaths),
           let pathsString = String(data: pathsData, encoding: .utf8) {
            settings["customPaths"] = pathsString
        }
        
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL)
        } catch {
            print("Error saving settings: \(error)")
        }
    }
    
    public func determineCategory(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        
        // Handle bundles first
        if url.hasDirectoryPath && [".app", ".logicx", ".vst3"].contains(".\(ext)") {
            if ext == "logicx" {
                return "Logic Projects"
            }
            return "Applications"
        }
        
        // Check if it's a screenshot
        let filename = url.lastPathComponent.lowercased()
        if ext == "png" || ext == "jpg" || ext == "jpeg" {
            if filename.contains("screenshot") || filename.contains("screen shot") {
                return "Screenshots"
            }
        }
        
        // Check categories
        for (category, extensions) in categories {
            if extensions.contains(".\(ext)") {
                return category
            }
        }
        
        return "Others"
    }
} 