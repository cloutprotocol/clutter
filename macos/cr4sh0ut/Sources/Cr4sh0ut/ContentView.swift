import SwiftUI
import UniformTypeIdentifiers

@available(macOS 14.0, *)
public struct ContentView: View {
    @State private var selectedPath: String = ""
    @State private var isProcessing = false
    @State private var filesProcessed = 0
    @State private var totalSizeProcessed: Int64 = 0
    @State private var statusMessage = "Ready"
    @State private var isDraggingOver = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Cr4sh0ut")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Drop zone with reactive grid
            ZStack {
                ReactiveGrid()
                    .frame(height: 200)
                    .opacity(isDraggingOver ? 0.8 : 0.4)
                    .animation(.easeInOut(duration: 0.2), value: isDraggingOver)
                
                VStack {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    Text("Drop files here")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDroppedFiles(providers)
                isDraggingOver = false
                return true
            }
            .onDragEnter { _ in
                isDraggingOver = true
            }
            .onDragExit { _ in
                isDraggingOver = false
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

// Drag and Drop modifiers
extension View {
    func onDragEnter(perform action: @escaping (DragInfo) -> Void) -> some View {
        self.onDrop(of: [.fileURL], isTargeted: nil) { providers, location in
            action(DragInfo(location: location, providers: providers))
            return false
        }
    }
    
    func onDragExit(perform action: @escaping (DragInfo) -> Void) -> some View {
        self.onDrop(of: [.fileURL], isTargeted: nil) { providers, location in
            action(DragInfo(location: location, providers: providers))
            return false
        }
    }
}

struct DragInfo {
    let location: CGPoint
    let providers: [NSItemProvider]
} 