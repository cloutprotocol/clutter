import SwiftUI
import QuickLookUI
import AppKit

public struct MediaView: View {
    let url: URL
    let urls: [URL]  // Array of all URLs for navigation
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var isFullscreen = false
    @State private var currentIndex: Int
    
    public init(url: URL, urls: [URL], isPresented: Binding<Bool>) {
        self.url = url
        self.urls = urls
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: urls.firstIndex(of: url) ?? 0)
    }
    
    public var body: some View {
        ZStack {
            // Background overlay
            Color.black
                .opacity(0.95)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isFullscreen {
                        isPresented = false
                    }
                }
            
            // Content
            VStack(spacing: 0) {
                if !isFullscreen {
                    toolbar
                }
                
                // Media content
                ZStack {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Prevent click-through
                        }
                    
                    // Navigation buttons
                    HStack {
                        if currentIndex > 0 {
                            navigationButton(direction: .previous)
                        }
                        Spacer()
                        if currentIndex < urls.count - 1 {
                            navigationButton(direction: .next)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Image
                    if let nsImage = NSImage(contentsOf: urls[currentIndex]) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { value in
                                        lastScale = scale
                                    }
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { value in
                                        lastOffset = offset
                                    }
                            )
                            .onTapGesture(count: 2) {
                                toggleFullscreen()
                            }
                    } else {
                        Text("Unable to load image")
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                if !isFullscreen {
                    infoBar
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                // Prevent click-through
            }
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                handleKeyEvent(event)
                return event
            }
        }
    }
    
    private var toolbar: some View {
        HStack {
            // Close button
            Button(action: { isPresented = false }) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                mediaButton("folder") {
                    NSWorkspace.shared.selectFile(urls[currentIndex].path, inFileViewerRootedAtPath: urls[currentIndex].deletingLastPathComponent().path)
                }
                
                mediaButton("arrow.up.right.square") {
                    NSWorkspace.shared.open(urls[currentIndex])
                }
                
                mediaButton(isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                    toggleFullscreen()
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }
    
    private var infoBar: some View {
        HStack {
            Text(urls[currentIndex].lastPathComponent)
                .font(.system(size: 14))
                .foregroundColor(.white)
            
            Spacer()
            
            if let resources = try? urls[currentIndex].resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resources.fileSize {
                Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }
    
    private func mediaButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .padding(8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func navigationButton(direction: NavigationDirection) -> some View {
        Button(action: { navigate(direction) }) {
            Image(systemName: direction == .next ? "chevron.right.circle.fill" : "chevron.left.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.6))
                .shadow(color: .black.opacity(0.5), radius: 4)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(direction == .next ? .rightArrow : .leftArrow, modifiers: [])
    }
    
    private func toggleFullscreen() {
        withAnimation(.spring()) {
            isFullscreen.toggle()
        }
        
        if let window = NSApplication.shared.windows.first {
            if !window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            } else if !isFullscreen {
                window.toggleFullScreen(nil)
            }
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        switch event.keyCode {
        case 123: // Left arrow
            if currentIndex > 0 {
                navigate(.previous)
            }
        case 124: // Right arrow
            if currentIndex < urls.count - 1 {
                navigate(.next)
            }
        case 53: // Escape
            if isFullscreen {
                toggleFullscreen()
            } else {
                isPresented = false
            }
        default:
            break
        }
    }
    
    private func navigate(_ direction: NavigationDirection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch direction {
            case .next:
                if currentIndex < urls.count - 1 {
                    currentIndex += 1
                }
            case .previous:
                if currentIndex > 0 {
                    currentIndex -= 1
                }
            }
            // Reset zoom and offset for new image
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }
    
    private enum NavigationDirection {
        case next, previous
    }
}

extension ByteCountFormatter {
    static func string(fromByteCount byteCount: Int64, countStyle: ByteCountFormatter.CountStyle) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = countStyle
        return formatter.string(fromByteCount: byteCount)
    }
} 