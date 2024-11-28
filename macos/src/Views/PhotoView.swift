import SwiftUI
import Cr4sh0utUI
import Cr4sh0utManagers
import QuickLookUI

struct MediaItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let modificationDate: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct PhotoView: View {
    @ObservedObject private var fileManager = FileManager.shared
    @ObservedObject private var viewRouter = ViewRouter.shared
    @State private var mediaItems: [MediaItem] = []
    @State private var selectedItem: MediaItem?
    @State private var isGridView = true
    @State private var folderSize: Int64 = 0
    @State private var isLoading = true
    @State private var gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
    @State private var showMediaView = false
    
    private let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    // Home button
                    Button(action: {
                        withAnimation {
                            viewRouter.currentView = .menu
                        }
                    }) {
                        Image(systemName: "house")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    // View toggle
                    Button(action: {
                        withAnimation {
                            isGridView.toggle()
                        }
                    }) {
                        Image(systemName: isGridView ? "square.grid.2x2" : "rectangle.grid.1x2")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Column adjustment
                    if isGridView {
                        Stepper("", value: Binding(
                            get: { gridColumns.count },
                            set: { newValue in
                                withAnimation {
                                    gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: max(2, min(6, newValue)))
                                }
                            }
                        ), in: 2...6)
                        .labelsHidden()
                    }
                }
                .padding()
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else if mediaItems.isEmpty {
                    Spacer()
                    Text("No photos found")
                        .foregroundColor(.white)
                        .font(.title2)
                    Spacer()
                } else {
                    // Content
                    if isGridView {
                        gridLayout
                    } else {
                        listLayout
                    }
                }
                
                // Footer with folder size
                HStack {
                    Text(formatFileSize(folderSize))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("\(mediaItems.count) items")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
                .padding()
                .background(Color.black.opacity(0.5))
            }
            
            // Media viewer overlay
            if showMediaView, let item = selectedItem {
                MediaView(
                    url: item.url,
                    urls: mediaItems.map { $0.url },
                    isPresented: $showMediaView
                )
            }
        }
        .task {
            await loadPhotos()
        }
    }
    
    private var gridLayout: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(mediaItems) { item in
                    AsyncImage(url: item.url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(height: 150)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .onTapGesture {
                        selectedItem = item
                        showMediaView = true
                    }
                }
            }
            .padding(8)
        }
    }
    
    private var listLayout: some View {
        List(mediaItems) { item in
            HStack(spacing: 16) {
                AsyncImage(url: item.url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)
                .clipped()
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.url.lastPathComponent)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(formatFileSize(item.size))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(item.modificationDate, style: .date)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
            }
            .listRowBackground(Color.clear)
            .onTapGesture {
                selectedItem = item
                showMediaView = true
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }
        
        let photosPath = fileManager.baseDir.appendingPathComponent("Images")
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: photosPath,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return }
        
        var items: [MediaItem] = []
        var totalSize: Int64 = 0
        
        for url in contents {
            guard imageExtensions.contains(url.pathExtension.lowercased()) else { continue }
            
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
               let fileSize = resourceValues.fileSize,
               let modDate = resourceValues.contentModificationDate {
                items.append(MediaItem(
                    url: url,
                    size: Int64(fileSize),
                    modificationDate: modDate
                ))
                totalSize += Int64(fileSize)
            }
        }
        
        await MainActor.run {
            self.mediaItems = items.sorted { $0.modificationDate > $1.modificationDate }
            self.folderSize = totalSize
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

#Preview {
    PhotoView()
} 