import SwiftUI
import UniformTypeIdentifiers
import Cr4sh0utUI
import Cr4sh0utManagers

public struct ContentView: View {
    @StateObject private var fileManager = FileManager.shared
    @State private var isProcessing = false
    @State private var filesProcessed = 0
    @State private var totalSizeProcessed: Int64 = 0
    @State private var statusMessage = "Ready"
    @State private var isDraggingOver = false
    @State private var showSettings = false
    
    // Custom button style for dark glassy effect
       struct DarkGlassButtonStyle: ViewModifier {
           func body(content: Content) -> some View {
               content
                   .buttonStyle(.plain)
                   .padding(8)
                   .background(
                       ZStack {
                           Color.black.opacity(0.3)
                           LinearGradient(
                               colors: [
                                   .white.opacity(0.07),
                                   .clear
                               ],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing
                           )
                       }
                   )
                   .overlay(
                       Circle()
                           .stroke(Color.white.opacity(0.07), lineWidth: 1)
                   )
                   .clipShape(Circle())
                   .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
           }
       }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ReactiveGrid()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack(spacing: 0) {
                HStack {
                    if Foundation.FileManager.default.fileExists(atPath: fileManager.baseDir.path) {
                        Button(action: {
                            NSWorkspace.shared.open(fileManager.baseDir)
                        }) {
                            Image(systemName: "folder")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .modifier(DarkGlassButtonStyle())
                        .help("Open cr4sh0ut folder")
                    }
                    
                    Spacer()
                    
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .modifier(DarkGlassButtonStyle())
                    .help("Settings")
                }
                .padding()
                
                VStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                            .padding()
                        Text("\(filesProcessed) files processed")
                            .foregroundColor(.white)
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .blur(radius: isDraggingOver ? 10 : 5)
                            
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                                .opacity(isDraggingOver ? 1 : 0.8)
                                .scaleEffect(isDraggingOver ? 1.1 : 1.0)
                                .animation(.spring(response: 0.3), value: isDraggingOver)
                        }
                        
                        Text("Drop files here")
                            .font(.title2)
                            .foregroundColor(.white)
                            .opacity(isDraggingOver ? 1 : 0.8)
                            .animation(.easeInOut(duration: 0.2), value: isDraggingOver)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 600)
                .contentShape(Rectangle())
                .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
                    Task {
                        await handleDrop(providers)
                    }
                    return true
                }
                
                Spacer()
                
                Text(statusMessage)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom)
                    .animation(.easeInOut(duration: 0.2), value: statusMessage)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
    
    private func handleDrop(_ providers: [NSItemProvider]) async {
        isProcessing = true
        filesProcessed = 0
        
        for provider in providers {
            if let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) {
                if let data = item as? Data,
                   let path = String(data: data, encoding: .utf8),
                   let url = URL(string: path) {
                    
                    do {
                        let fileURL = url.standardized
                        try await processFile(at: fileURL)
                        filesProcessed += 1
                        withAnimation {
                            statusMessage = "Processed: \(fileURL.lastPathComponent)"
                        }
                    } catch {
                        withAnimation {
                            statusMessage = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
        
        isProcessing = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                statusMessage = "Ready"
            }
        }
    }
    
    private func processFile(at url: URL) async throws {
        let category = fileManager.determineCategory(for: url)
        let destinationURL = fileManager.baseDir.appendingPathComponent(category)
        
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        
        let finalURL = destinationURL.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: finalURL.path) {
            switch fileManager.currentDuplicateHandling {
            case "skip":
                return
            case "replace":
                try FileManager.default.removeItem(at: finalURL)
            case "rename":
                var counter = 1
                var newURL = finalURL
                while FileManager.default.fileExists(atPath: newURL.path) {
                    let filename = url.deletingPathExtension().lastPathComponent
                    let ext = url.pathExtension
                    newURL = destinationURL.appendingPathComponent("\(filename)_\(counter).\(ext)")
                    counter += 1
                }
                try FileManager.default.moveItem(at: url, to: newURL)
                return
            default:
                break
            }
        }
        
        try FileManager.default.moveItem(at: url, to: finalURL)
    }
}

#Preview {
    ContentView()
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
}
