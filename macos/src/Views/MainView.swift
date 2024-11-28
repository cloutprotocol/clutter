import SwiftUI
import UniformTypeIdentifiers
import Cr4sh0utUI
import Cr4sh0utManagers

public struct MainView: View {
    @StateObject private var fileManager = FileManager.shared
    @ObservedObject private var viewRouter = ViewRouter.shared
    @State private var isProcessing = false
    @State private var filesProcessed = 0
    @State private var isDraggingOver = false
    @State private var statusMessage = "Ready"
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
    
    public var body: some View {
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
                
                Menu {
                    Button(action: {
                        viewRouter.currentView = .menu
                    }) {
                        Label("Menu", systemImage: "square.grid.2x2")
                    }
                    
                    Button(action: {
                        viewRouter.currentView = .about
                    }) {
                        Label("About", systemImage: "info.circle")
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text("cr4sh0ut")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            // Base layer
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                            
                            // Glitch effect layers
                            GlitchEffect()
                            
                            // Border glow
                            Rectangle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.cyan.opacity(0.7),
                                            Color.blue.opacity(0.5),
                                            Color.purple.opacity(0.7)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: Color.cyan.opacity(0.3), radius: 5, x: 0, y: 0)
                }
                .menuStyle(GlassMenuStyle())
                .help("Navigation Menu")
                
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
        .overlay(
            SlideOutSettings(isPresented: $showSettings)
        )
    }
    
    @MainActor
    private func handleDrop(_ providers: [NSItemProvider]) async {
        isProcessing = true
        filesProcessed = 0
        
        for provider in providers {
            do {
                let item = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<NSSecureCoding?, Error>) in
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: item)
                        }
                    }
                }
                
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
            } catch {
                withAnimation {
                    statusMessage = "Error loading file: \(error.localizedDescription)"
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

struct SlideOutSettings: View {
    @Binding var isPresented: Bool
    @State private var offset: CGFloat = 400
    
    var body: some View {
        GeometryReader { geometry in
            if isPresented {
                HStack(spacing: 0) {
                    Spacer()
                    
                    // Settings Panel
                    VStack(spacing: 0) {
                        // Header
                        HStack {
                            Text("Settings")
                                .font(.title2)
                                .foregroundColor(.white)
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isPresented = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color.black.opacity(0.3))
                        
                        // Settings Content
                        SettingsView()
                            .background(Color.black.opacity(0.2))
                    }
                    .frame(width: 400)
                    .background(
                        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    )
                    .offset(x: offset)
                }
                .transition(.opacity)
                .onAppear {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offset = 0
                    }
                }
            }
        }
        .onChange(of: isPresented) { newValue in
            if !newValue {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    offset = 400
                }
            }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }
    
    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct GlassMenuStyle: MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .background(
                TranslucentBackground()
            )
    }
}

struct TranslucentBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct GlitchEffect: View {
    @State private var isAnimating = false
    @State private var glitchOffset: CGFloat = 0
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Random glitch blocks
                ForEach(0..<3) { index in
                    Rectangle()
                        .fill(Color.cyan.opacity(0.1))
                        .frame(
                            width: CGFloat.random(in: 5...20),
                            height: CGFloat.random(in: 2...4)
                        )
                        .offset(
                            x: isAnimating ? CGFloat.random(in: -10...10) : 0,
                            y: isAnimating ? geometry.size.height * CGFloat.random(in: -0.5...0.5) : 0
                        )
                        .opacity(isAnimating ? 1 : 0)
                }
                
                // Scanning line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .cyan.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 10)
                    .offset(y: glitchOffset)
                    .opacity(0.5)
                
                // Horizontal glitch lines
                ForEach(0..<2) { index in
                    Rectangle()
                        .fill(index == 0 ? Color.cyan.opacity(0.2) : Color.purple.opacity(0.2))
                        .frame(height: 1)
                        .offset(
                            x: isAnimating ? CGFloat.random(in: -2...2) : 0,
                            y: isAnimating ? geometry.size.height * (index == 0 ? 0.3 : -0.3) : 0
                        )
                        .opacity(isAnimating ? 1 : 0)
                }
            }
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
            .onReceive(timer) { _ in
                withAnimation(.linear(duration: 0.8)) {
                    glitchOffset = CGFloat.random(in: -20...20)
                }
            }
        }
    }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .frame(width: 800, height: 600)
            .preferredColorScheme(.dark)
            .background(Color.black)
    }
}
#endif 
