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
    
    public init() {
        _tempBaseDir = State(initialValue: FileManager.shared.baseDir.path)
        _duplicateHandling = State(initialValue: FileManager.shared.currentDuplicateHandling)
    }
    
    public var body: some View {
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
                    Text("Rename").tag("rename")
                    Text("Skip").tag("skip")
                    Text("Replace").tag("replace")
                }
                .pickerStyle(.segmented)
                .padding(.top, 8)
            }
            .padding(.horizontal)
        }
    }
    
    private var fileTypeSettings: some View {
        VStack {
            ForEach(Array(fileManager.categories.keys.sorted()), id: \.self) { category in
                categoryRow(category)
            }
        }
        .padding()
    }
    
    private func categoryRow(_ category: String) -> some View {
        HStack {
            Text(category)
            Spacer()
            Button(action: {
                // Handle category customization
            }) {
                Image(systemName: "folder")
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
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