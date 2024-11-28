import SwiftUI
import UniformTypeIdentifiers

public struct ContentView: View {
    @State private var selectedPath: String = ""
    @State private var isProcessing = false
    @State private var filesProcessed = 0
    @State private var totalSizeProcessed: Int64 = 0
    @State private var statusMessage = "Ready"
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Cr4sh0ut")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Drop zone
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 30))
                            Text("Drop files here")
                                .font(.headline)
                        }
                    )
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDroppedFiles(providers)
                return true
            }
            
            // Progress section
            VStack(alignment: .leading, spacing: 10) {
                Text("Files processed: \(filesProcessed)")
                Text("Total size: \(formatSize(totalSizeProcessed))")
                Text("Status: \(statusMessage)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Manual selection button
            Button("Select Files") {
                selectFiles()
            }
            .disabled(isProcessing)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func handleDroppedFiles(_ providers: [NSItemProvider]) {
        isProcessing = true
        
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                DispatchQueue.main.async {
                    processFile(at: url)
                }
            }
        }
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        
        panel.begin { response in
            if response == .OK {
                for url in panel.urls {
                    processFile(at: url)
                }
            }
        }
    }
    
    private func processFile(at url: URL) {
        do {
            try FileSystemManager.shared.organizeFile(at: url)
            filesProcessed += 1
            totalSizeProcessed += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
            statusMessage = "Processed: \(url.lastPathComponent)"
        } catch {
            statusMessage = "Error processing \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
    
    private func formatSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
} 