import SwiftUI
import Cr4sh0utManagers

public struct SettingsView: View {
    @ObservedObject var fileManager = FileManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var duplicateHandling = "rename"
    @State private var tempBaseDir: String
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var selectedTab = 0
    @State private var expandedCategories: Set<String> = []
    
    public init() {
        _tempBaseDir = State(initialValue: FileManager.shared.baseDir.path)
        _duplicateHandling = State(initialValue: FileManager.shared.currentDuplicateHandling)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
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
        .alert("Settings", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var generalSettings: some View {
        VStack(spacing: 24) {
            // Output Directory Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Output Directory")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    TextField("Base Directory", text: $tempBaseDir)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    
                    Button(action: selectDirectory) {
                        Image(systemName: "folder")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal)
            
            // Duplicate Handling Section
            VStack(alignment: .leading, spacing: 12) {
                Text("When file already exists")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Picker("", selection: $duplicateHandling) {
                    Text("Rename").tag("rename")
                    Text("Skip").tag("skip")
                    Text("Replace").tag("replace")
                }
                .pickerStyle(.segmented)
                .padding(4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            // Save Button
            Button(action: saveSettings) {
                Text("Save Changes")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.top, 12)
            
            Spacer()
        }
        .padding(.top, 20)
    }
    
    private var fileTypeSettings: some View {
        VStack(spacing: 16) {
            ForEach(Array(fileManager.categories.keys.sorted()), id: \.self) { category in
                categorySection(category)
            }
            Spacer()
        }
        .padding()
    }
    
    private func categorySection(_ category: String) -> some View {
        VStack(spacing: 0) {
            // Category Header
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if expandedCategories.contains(category) {
                            expandedCategories.remove(category)
                        } else {
                            expandedCategories.insert(category)
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(expandedCategories.contains(category) ? 90 : 0))
                            .foregroundColor(.white)
                        
                        Text(category)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if let customPath = fileManager.getCustomPath(for: category) {
                            Text(customPath.components(separatedBy: "/").last ?? "")
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        
                        Button(action: {
                            selectCustomPath(for: category)
                        }) {
                            Image(systemName: "folder")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            // Expanded Content
            if expandedCategories.contains(category) {
                VStack(alignment: .leading, spacing: 8) {
                    if let extensions = fileManager.categories[category], !extensions.isEmpty {
                        Text("File Types:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                        
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 8)
                        ], spacing: 8) {
                            ForEach(extensions.sorted(), id: \.self) { ext in
                                Text(ext)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(4)
                            }
                        }
                    } else {
                        Text("Auto-detected")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    }
                    
                    if let customPath = fileManager.getCustomPath(for: category) {
                        Text("Custom Path:")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                        
                        Text(customPath)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func selectCustomPath(for category: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select custom folder for \(category)"
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                fileManager.updateMapping(category: category, path: url.path)
            }
        }
    }
    
    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            tempBaseDir = panel.url?.path ?? ""
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

#Preview("Settings") {
    SettingsView()
        .frame(width: 700, height: 600)
        .preferredColorScheme(.dark)
} 