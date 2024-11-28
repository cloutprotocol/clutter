import SwiftUI
import UniformTypeIdentifiers
import Cr4sh0utUI

public struct ContentView: View {
    @State private var selectedPath: String = ""
    @State private var isProcessing = false
    @State private var filesProcessed = 0
    @State private var totalSizeProcessed: Int64 = 0
    @State private var statusMessage = "Ready"
    @State private var isDraggingOver = false
    @State private var showSettings = false
    @State private var fileTypes: [String: String] = [:]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ReactiveGrid()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding()
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
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
