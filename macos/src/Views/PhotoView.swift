import SwiftUI
import Cr4sh0utUI
import Cr4sh0utManagers
import Foundation

// MARK: - Models
struct MediaItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: Int64
    let modificationDate: Date
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)  // Use URL for uniqueness
    }
    
    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.url == rhs.url
    }
}

// MARK: - View Model
@MainActor
final class PhotoViewModel: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var folderSize: Int64 = 0
    @Published private(set) var totalStats: FolderStats?
    
    private var hasMoreContent = true
    private var loadedURLs: Set<URL> = []
    private let batchSize = 50
    private let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
    private let appFileManager: Cr4sh0utManagers.FileManager
    
    struct FolderStats {
        let totalFiles: Int
        let totalSize: Int64
    }
    
    init(fileManager: Cr4sh0utManagers.FileManager) {
        self.appFileManager = fileManager
    }
    
    func loadInitialContent() async {
        guard !isLoading else { return }
        isLoading = true
        items = []
        folderSize = 0
        loadedURLs.removeAll()
        
        // Calculate total stats first
        await calculateTotalStats()
        
        // Then start loading content
        await loadMoreContent()
        isLoading = false
    }
    
    private func calculateTotalStats() async {
        let photosPath = appFileManager.baseDir.appendingPathComponent("Images")
        guard let contents = try? Foundation.FileManager.default.contentsOfDirectory(
            at: photosPath,
            includingPropertiesForKeys: [URLResourceKey.fileSizeKey, URLResourceKey.contentModificationDateKey]
        ) else { return }
        
        let imageFiles = contents.filter { url in
            imageExtensions.contains(url.pathExtension.lowercased())
        }
        
        var totalSize: Int64 = 0
        for url in imageFiles {
            if let resourceValues = try? url.resourceValues(forKeys: [URLResourceKey.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        self.totalStats = FolderStats(totalFiles: imageFiles.count, totalSize: totalSize)
    }
    
    func checkLoadMore(currentIndex: Int) async {
        let threshold = items.count - 20
        if currentIndex > threshold {
            await loadMoreContent()
        }
    }
    
    private func loadMoreContent() async {
        guard !isLoadingMore && hasMoreContent else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        let photosPath = appFileManager.baseDir.appendingPathComponent("Images")
        guard let contents = try? Foundation.FileManager.default.contentsOfDirectory(
            at: photosPath,
            includingPropertiesForKeys: [URLResourceKey.fileSizeKey, URLResourceKey.contentModificationDateKey]
        ) else { return }
        
        // Get unprocessed image URLs
        let newURLs = contents.filter { url in
            imageExtensions.contains(url.pathExtension.lowercased()) && !loadedURLs.contains(url)
        }
        
        guard !newURLs.isEmpty else {
            hasMoreContent = false
            return
        }
        
        // Sort by modification date
        let sortedURLs = newURLs.sorted { url1, url2 in
            guard let date1 = try? url1.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate,
                  let date2 = try? url2.resourceValues(forKeys: [URLResourceKey.contentModificationDateKey]).contentModificationDate else {
                return false
            }
            return date1 > date2
        }
        
        // Process batch
        let batchURLs = sortedURLs.prefix(batchSize)
        let (newItems, newSize) = await processURLBatch(Array(batchURLs))
        
        self.items.append(contentsOf: newItems)
        self.folderSize += newSize
    }
    
    private func processURLBatch(_ urls: [URL]) async -> ([MediaItem], Int64) {
        var items: [MediaItem] = []
        var totalSize: Int64 = 0
        
        for url in urls {
            guard !loadedURLs.contains(url) else { continue }
            
            if let resourceValues = try? url.resourceValues(forKeys: [URLResourceKey.fileSizeKey, URLResourceKey.contentModificationDateKey]),
               let fileSize = resourceValues.fileSize,
               let modDate = resourceValues.contentModificationDate {
                items.append(MediaItem(
                    url: url,
                    size: Int64(fileSize),
                    modificationDate: modDate
                ))
                totalSize += Int64(fileSize)
                loadedURLs.insert(url)
            }
        }
        
        return (items, totalSize)
    }
}

// MARK: - Main View
struct PhotoView: View {
    @StateObject private var viewModel: PhotoViewModel
    @ObservedObject private var viewRouter = ViewRouter.shared
    @State private var selectedItem: MediaItem?
    @State private var showMediaView = false
    @State private var isGridView = true
    @State private var gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
    
    private let thumbnailQueue = DispatchQueue(label: "com.cr4sh0ut.thumbnailQueue", qos: .userInitiated, attributes: .concurrent)
    private let thumbnailCache = NSCache<NSURL, NSImage>()
    
    init(fileManager: Cr4sh0utManagers.FileManager = .shared) {
        _viewModel = StateObject(wrappedValue: PhotoViewModel(fileManager: fileManager))
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                toolbar
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else if viewModel.items.isEmpty {
                    Spacer()
                    Text("No photos found")
                        .foregroundColor(.white)
                        .font(.title2)
                    Spacer()
                } else {
                    if isGridView {
                        gridLayout
                    } else {
                        listLayout
                    }
                }
                
                footer
            }
            
            if showMediaView, let item = selectedItem {
                MediaView(
                    url: item.url,
                    urls: viewModel.items.map(\.url),
                    isPresented: $showMediaView
                )
            }
        }
        .task {
            await viewModel.loadInitialContent()
        }
    }
    
    private var toolbar: some View {
        HStack {
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
            
            if isGridView {
                Stepper("", value: Binding(
                    get: { gridColumns.count },
                    set: { newValue in
                        withAnimation {
                            gridColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: max(2, min(6, newValue)))
                        }
                    }
                ), in: 2...6)
                .labelsHidden()
            }
        }
        .padding()
    }
    
    private var gridLayout: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    AsyncThumbnail(item: item, cache: thumbnailCache, thumbnailQueue: thumbnailQueue)
                        .frame(height: 180)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedItem = item
                            showMediaView = true
                        }
                        .task {
                            await viewModel.checkLoadMore(currentIndex: index)
                        }
                }
            }
            .padding(12)
        }
    }
    
    private var listLayout: some View {
        List(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
            HStack(spacing: 16) {
                AsyncThumbnail(item: item, cache: thumbnailCache, thumbnailQueue: thumbnailQueue)
                    .frame(width: 100, height: 100)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .contentShape(Rectangle())
                
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
                
                Button(action: {
                    NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: item.url.deletingLastPathComponent().path)
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .padding(8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.clear)
            .onTapGesture {
                selectedItem = item
                showMediaView = true
            }
            .task {
                await viewModel.checkLoadMore(currentIndex: index)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private var footer: some View {
        HStack {
            if let stats = viewModel.totalStats {
                Text(formatFileSize(stats.totalSize))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("•")
                    .foregroundColor(.white.opacity(0.5))
                
                Text("\(stats.totalFiles) total files")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("•")
                    .foregroundColor(.white.opacity(0.5))
                
                Text("\(viewModel.items.count) loaded")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Thumbnail Component
struct AsyncThumbnail: View {
    let item: MediaItem
    let cache: NSCache<NSURL, NSImage>
    let thumbnailQueue: DispatchQueue
    @State private var thumbnail: NSImage?
    
    var body: some View {
        Group {
            if let image = thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black.opacity(0.3)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        if let cached = cache.object(forKey: item.url as NSURL) {
            thumbnail = cached
            return
        }
        
        thumbnailQueue.async {
            guard let image = NSImage(contentsOf: item.url)?.thumbnail(size: NSSize(width: 400, height: 400)) else { return }
            cache.setObject(image, forKey: item.url as NSURL)
            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.2)) {
                    thumbnail = image
                }
            }
        }
    }
}

extension NSImage {
    func thumbnail(size: NSSize) -> NSImage {
        let scale = size.width / self.size.width
        let newSize = NSSize(width: self.size.width * scale, height: self.size.height * scale)
        let thumbnailImage = NSImage(size: newSize)
        
        thumbnailImage.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: newSize),
                 from: NSRect(origin: .zero, size: self.size),
                 operation: .sourceOver,
                 fraction: 1.0)
        thumbnailImage.unlockFocus()
        
        return thumbnailImage
    }
}

#Preview {
    PhotoView()
} 