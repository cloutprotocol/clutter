import SwiftUI

struct SettingsView: View {
    @ObservedObject var fileManager = FileSystemManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var duplicateHandling = "rename"
    @State private var tempBaseDir: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedTab = 0
    
    init() {
        _tempBaseDir = State(initialValue: FileSystemManager.shared.baseDir.path)
        _duplicateHandling = State(initialValue: FileSystemManager.shared.currentDuplicateHandling)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Button("Save") {
                        saveSettings()
                    }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Tab Selection
            Picker("", selection: $selectedTab) {
                Text("General").tag(0)
                Text("File Types").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            ScrollView {
                if selectedTab == 0 {
                    generalSettings
                } else {
                    fileTypeSettings
                }
            }
        }
        .frame(width: 700, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Settings", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var generalSettings: some View {
        VStack(spacing: 20) {
            // Output Directory Section
            GroupBox(label: Text("Output Directory").font(.headline)) {
                HStack {
                    TextField("Base Directory", text: $tempBaseDir)
                        .textFieldStyle(.roundedBorder)
                    Button(action: selectDirectory) {
                        Image(systemName: "folder")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
            
            // Duplicate Handling Section
            GroupBox(label: Text("When file already exists").font(.headline)) {
                Picker("", selection: $duplicateHandling) {
                    Text("Auto-rename").tag("rename")
                    Text("Skip").tag("skip")
                    Text("Replace").tag("replace")
                }
                .pickerStyle(.segmented)
                .padding(.top, 8)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var fileTypeSettings: some View {
        VStack(spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 0) {
                    Text("File Type Mappings")
                        .font(.headline)
                        .padding(.bottom, 8)
                    
                    Text("By default, files are organized into category folders within the output directory. You can override specific categories to use custom locations.")
                        .foregroundColor(.secondary)
                        .padding(.bottom, 16)
                    
                    Divider()
                        .padding(.bottom, 16)
                    
                    VStack(spacing: 16) {
                        // Header
                        HStack {
                            Text("Category")
                                .fontWeight(.medium)
                                .frame(width: 150, alignment: .leading)
                            Text("Extensions")
                                .fontWeight(.medium)
                                .frame(minWidth: 200, alignment: .leading)
                            Text("")
                                .frame(width: 120)
                        }
                        .foregroundColor(.secondary)
                        
                        // Categories
                        ForEach(Array(fileManager.categories.keys.sorted()), id: \.self) { category in
                            VStack(spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(category)
                                            .fontWeight(.medium)
                                        if let customPath = fileManager.getCustomPath(for: category) {
                                            Text(customPath)
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .frame(width: 150, alignment: .leading)
                                    
                                    Text(fileManager.categories[category]?.joined(separator: ", ") ?? "")
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .frame(minWidth: 200, alignment: .leading)
                                    
                                    HStack {
                                        if fileManager.getCustomPath(for: category) != nil {
                                            Button("Change") {
                                                selectMappingDirectory(for: category)
                                            }
                                            Button(action: { fileManager.updateMapping(category: category, path: "") }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.borderless)
                                            .help("Reset to default")
                                        } else {
                                            Button("Set Custom Path") {
                                                selectMappingDirectory(for: category)
                                            }
                                        }
                                    }
                                    .frame(width: 120)
                                }
                                
                                Divider()
                            }
                        }
                    }
                }
                .padding()
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose output directory for organized files"
        panel.prompt = "Select"
        
        panel.begin { response in
            if response == .OK {
                if let url = panel.urls.first {
                    tempBaseDir = url.path
                }
            }
        }
    }
    
    private func selectMappingDirectory(for category: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose directory for \(category) files"
        panel.prompt = "Select"
        
        if let currentPath = fileManager.getCustomPath(for: category) {
            panel.directoryURL = URL(fileURLWithPath: currentPath)
        }
        
        panel.begin { response in
            if response == .OK {
                if let url = panel.urls.first {
                    fileManager.updateMapping(category: category, path: url.path)
                }
            }
        }
    }
    
    private func saveSettings() {
        do {
            try fileManager.updateBaseDir(path: tempBaseDir)
            fileManager.saveDuplicateHandling(duplicateHandling)
            alertMessage = "Settings saved successfully"
            showingAlert = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                dismiss()
            }
        } catch {
            alertMessage = "Error saving settings: \(error.localizedDescription)"
            showingAlert = true
        }
    }
} 