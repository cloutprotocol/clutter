import SwiftUI
import Cr4sh0utUI
import Cr4sh0utManagers
import Foundation
import AVFoundation
import AudioKit
import AudioKitUI

// MARK: - Models
struct AudioItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let title: String
    let artist: String?
    let duration: TimeInterval
    let size: Int64
    let modificationDate: Date
    let fileType: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: AudioItem, rhs: AudioItem) -> Bool {
        lhs.url == rhs.url
    }
}

// MARK: - View Model
@MainActor
final class MusicViewModel: ObservableObject {
    @Published private(set) var items: [AudioItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var totalStats: FolderStats?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlaying = false
    @Published var currentTrack: AudioItem?
    @Published var volume: Float = 0.7
    @Published var visualizerStyle: VisualizerStyle = .spectrum
    @Published var isShuffleEnabled = false
    @Published var repeatMode: RepeatMode = .none
    @Published var fftData: [Float] = Array(repeating: 0, count: 512)
    @Published var previewTime: Double?
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private let audioExtensions = ["mp3", "m4a", "wav", "aac"]
    private let appFileManager: Cr4sh0utManagers.FileManager
    private var engine = AudioEngine()
    private var mixer: Mixer?
    private var player1: AudioPlayer?
    private var fft: FFTTap?
    private var silencePlayer: AudioPlayer?
    private var currentBuffer: AVAudioPCMBuffer?
    
    enum VisualizerStyle: String, CaseIterable {
        case spectrum, oscilloscope, waveform
    }
    
    enum RepeatMode: CaseIterable {
        case none, one, all
        
        var icon: String {
            switch self {
            case .none: return "repeat"
            case .one: return "repeat.1"
            case .all: return "repeat"
            }
        }
        
        var color: Color {
            switch self {
            case .none: return .white.opacity(0.7)
            case .one, .all: return .green
            }
        }
    }
    
    struct FolderStats {
        let totalFiles: Int
        let totalSize: Int64
    }
    
    init(fileManager: Cr4sh0utManagers.FileManager) {
        self.appFileManager = fileManager
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        do {
            mixer = Mixer()
            guard let mixer = mixer else { return }
            
            // Create a silence player to keep engine running
            let silence = AudioPlayer()
            silencePlayer = silence
            
            engine.output = mixer
            try engine.start()
            
            // Create FFT tap on mixer output
            fft = FFTTap(mixer) { [weak self] fftData in
                self?.updateFFT(fftData)
            }
        } catch {
            print("Error setting up audio engine: \(error)")
        }
    }
    
    private func updateFFT(_ data: [Float]) {
        // Normalize and smooth the FFT data
        for i in 0..<min(data.count, fftData.count) {
            let value = data[i]
            let normalizedValue = max(0, min(1, (20 * log10f(value) + 60) / 60))
            fftData[i] = fftData[i] * 0.8 + normalizedValue * 0.2
        }
    }
    
    func playTrack(_ item: AudioItem) {
        currentTrack = item
        duration = item.duration
        currentTime = 0
        
        // Setup AVPlayer for timeline tracking
        let playerItem = AVPlayerItem(url: item.url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        setupTimeObserver()
        
        // Setup AudioKit player
        do {
            if let existingPlayer = player1 {
                mixer?.removeInput(existingPlayer)
                existingPlayer.stop()
            }
            
            let file = try AVAudioFile(forReading: item.url)
            let newPlayer = AudioPlayer(file: file)
            player1 = newPlayer
            
            if let mixer = mixer, let player = newPlayer {
                mixer.addInput(player)
                player.play()
                fft?.start()
            }
            
            player?.volume = volume
            player?.play()
            isPlaying = true
        } catch {
            print("Error playing file: \(error)")
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            player1?.pause()
            player?.pause()
        } else {
            player1?.play()
            player?.play()
        }
        isPlaying.toggle()
    }
    
    func setVolume(_ value: Float) {
        volume = value
        player1?.volume = value
        player?.volume = value
    }
    
    private func setupTimeObserver() {
        // Remove existing observer if any
        if let existingObserver = timeObserver {
            player?.removeTimeObserver(existingObserver)
        }
        
        // Create new observer with shorter interval for smoother updates
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
                
                // Handle track completion
                if self.currentTime >= self.duration {
                    if self.repeatMode == .one {
                        self.seek(to: 0)
                        self.player1?.play()
                        self.player?.play()
                    } else {
                        self.playNext()
                    }
                }
            }
        }
    }
    
    func seek(to percentage: Double) {
        guard let player = player else { return }
        let targetTime = duration * percentage
        let time = CMTime(seconds: targetTime, preferredTimescale: 600)
        player.seek(to: time) { [weak self] _ in
            if let player = self?.player1 {
                player.seek(time: targetTime)
            }
        }
        currentTime = targetTime
    }
    
    func playNext() {
        guard let current = currentTrack,
              let currentIndex = items.firstIndex(of: current) else { return }
        
        var nextIndex: Int
        if isShuffleEnabled {
            nextIndex = Int.random(in: 0..<items.count)
            while nextIndex == currentIndex && items.count > 1 {
                nextIndex = Int.random(in: 0..<items.count)
            }
        } else {
            nextIndex = currentIndex + 1
            if nextIndex >= items.count {
                if repeatMode == .all {
                    nextIndex = 0
                } else {
                    return
                }
            }
        }
        
        playTrack(items[nextIndex])
    }
    
    func playPrevious() {
        guard let current = currentTrack,
              let currentIndex = items.firstIndex(of: current),
              currentIndex > 0 else { return }
        playTrack(items[currentIndex - 1])
    }
    
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled {
            items.shuffle()
        } else {
            items.sort { $0.title < $1.title }
        }
    }
    
    func toggleRepeat() {
        switch repeatMode {
        case .none: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .none
        }
    }
    
    func openInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
    }
    
    func openFile(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        player1?.stop()
        fft?.stop()
        engine.stop()
    }
    
    func loadContent() async {
        guard !isLoading else { return }
        isLoading = true
        items = []
        
        let audioPath = appFileManager.baseDir.appendingPathComponent("Audio")
        guard let contents = try? Foundation.FileManager.default.contentsOfDirectory(
            at: audioPath,
            includingPropertiesForKeys: [URLResourceKey.fileSizeKey, URLResourceKey.contentModificationDateKey]
        ) else {
            isLoading = false
            return
        }
        
        let audioFiles = contents.filter { url in
            audioExtensions.contains(url.pathExtension.lowercased())
        }
        
        var totalSize: Int64 = 0
        var newItems: [AudioItem] = []
        
        for url in audioFiles {
            if let resourceValues = try? url.resourceValues(forKeys: [URLResourceKey.fileSizeKey, URLResourceKey.contentModificationDateKey]),
               let fileSize = resourceValues.fileSize,
               let modDate = resourceValues.contentModificationDate {
                
                let asset = AVAsset(url: url)
                let duration = try? await asset.load(.duration)
                let metadata = try? await asset.load(.commonMetadata)
                
                let titleItem = metadata?.first(where: { $0.commonKey == .commonKeyTitle })
                let artistItem = metadata?.first(where: { $0.commonKey == .commonKeyArtist })
                
                let title = (try? await titleItem?.load(.stringValue)) ?? url.deletingPathExtension().lastPathComponent
                let artist = try? await artistItem?.load(.stringValue)
                
                newItems.append(AudioItem(
                    url: url,
                    title: title,
                    artist: artist,
                    duration: duration?.seconds ?? 0,
                    size: Int64(fileSize),
                    modificationDate: modDate,
                    fileType: url.pathExtension.lowercased()
                ))
                totalSize += Int64(fileSize)
            }
        }
        
        self.items = newItems.sorted { $0.title < $1.title }
        self.totalStats = FolderStats(totalFiles: audioFiles.count, totalSize: totalSize)
        isLoading = false
    }
}

// MARK: - Visualizer Views
struct AudioSpectrumView: View {
    let fftData: [Float]
    @State private var hue: Double = 0
    
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                // Update color
                hue = (hue + 0.001).truncatingRemainder(dividingBy: 1.0)
                let baseColor = Color(hue: hue, saturation: 1, brightness: 1)
                
                let barWidth: CGFloat = size.width / CGFloat(fftData.count)
                let scaleFactor = size.height
                
                for i in 0..<fftData.count {
                    let magnitude = CGFloat(fftData[i])
                    let height = magnitude * scaleFactor
                    
                    let rect = Path(CGRect(
                        x: CGFloat(i) * barWidth,
                        y: size.height - height,
                        width: barWidth * 0.8,
                        height: height
                    ))
                    
                    context.fill(
                        rect,
                        with: .linearGradient(
                            Gradient(colors: [
                                baseColor.opacity(0.8),
                                baseColor.opacity(0.2)
                            ]),
                            startPoint: CGPoint(x: 0, y: size.height),
                            endPoint: CGPoint(x: 0, y: size.height - height)
                        )
                    )
                }
            }
        }
    }
}

// Add these structs before PlayerView
private func formatTime(_ time: Double) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
}

struct WinampScrubber: View {
    @ObservedObject var viewModel: MusicViewModel
    @State private var isDragging = false
    @State private var localPosition: CGFloat = 0
    @State private var showTooltip = false
    let height: CGFloat = 10
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background groove
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(Color.black.opacity(0.8), lineWidth: 1)
                    )
                
                // Progress bar
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.green.opacity(0.8), Color.green.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: currentWidth(in: geometry))
                
                // Mini peaks visualization
                ForEach(0..<Int(geometry.size.width/3), id: \.self) { index in
                    let x = CGFloat(index) * 3
                    let height = CGFloat.random(in: 2...6)
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 1, height: height)
                        .offset(x: x, y: (10 - height) / 2)
                }
                
                // Playhead
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2)
                    .frame(height: height + 4)
                    .position(x: currentPosition(in: geometry), y: height/2)
                    .shadow(color: .black.opacity(0.5), radius: 1)
                
                // Tooltip
                if showTooltip {
                    Text(formatTime(tooltipTime(in: geometry)))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(4)
                        .position(x: currentPosition(in: geometry), y: -15)
                }
            }
            .frame(height: height)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        showTooltip = true
                        localPosition = min(max(0, value.location.x), geometry.size.width)
                        let percentage = localPosition / geometry.size.width
                        viewModel.seek(to: percentage * viewModel.duration)
                    }
                    .onEnded { _ in
                        isDragging = false
                        showTooltip = false
                    }
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        showTooltip = true
                    }
                    .onEnded { _ in
                        showTooltip = false
                    }
            )
        }
    }
    
    private func currentWidth(in geometry: GeometryProxy) -> CGFloat {
        if isDragging {
            return localPosition
        }
        return geometry.size.width * CGFloat(viewModel.currentTime / max(viewModel.duration, 1))
    }
    
    private func currentPosition(in geometry: GeometryProxy) -> CGFloat {
        if isDragging {
            return localPosition
        }
        return geometry.size.width * CGFloat(viewModel.currentTime / max(viewModel.duration, 1))
    }
    
    private func tooltipTime(in geometry: GeometryProxy) -> Double {
        let percentage = currentPosition(in: geometry) / geometry.size.width
        return percentage * viewModel.duration
    }
}

struct WinampVolume: View {
    @Binding var volume: Float
    @State private var isDragging = false
    @State private var localVolume: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background groove
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(Color.black.opacity(0.8), lineWidth: 1)
                    )
                
                // Volume level
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color.green.opacity(0.8), Color.green.opacity(0.4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: currentWidth(in: geometry))
                
                // Volume handle
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.white)
                    .frame(width: 3, height: geometry.size.height + 1)
                    .position(x: currentPosition(in: geometry), y: geometry.size.height/2)
                    .shadow(color: .black.opacity(0.5), radius: 1)
            }
            .frame(height: 6)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        localVolume = min(max(0, value.location.x), geometry.size.width)
                        volume = Float(localVolume / geometry.size.width)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
    
    private func currentWidth(in geometry: GeometryProxy) -> CGFloat {
        if isDragging {
            return localVolume
        }
        return geometry.size.width * CGFloat(volume)
    }
    
    private func currentPosition(in geometry: GeometryProxy) -> CGFloat {
        if isDragging {
            return localVolume
        }
        return geometry.size.width * CGFloat(volume)
    }
}

// Update view declarations
public struct MusicView: View {
    @StateObject private var viewModel: MusicViewModel
    @ObservedObject private var viewRouter = ViewRouter.shared
    @State private var showingPlaylist = true
    
    public init(fileManager: Cr4sh0utManagers.FileManager = .shared) {
        _viewModel = StateObject(wrappedValue: MusicViewModel(fileManager: fileManager))
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                CompactHeaderView(viewRouter: viewRouter, showingPlaylist: $showingPlaylist)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    PlayerView(viewModel: viewModel)
                        .frame(height: 160)
                    
                    if showingPlaylist {
                        PlaylistView(viewModel: viewModel)
                    }
                }
            }
        }
        .task {
            await viewModel.loadContent()
        }
    }
}

private struct CompactHeaderView: View {
    @ObservedObject var viewRouter: ViewRouter
    @Binding var showingPlaylist: Bool
    
    var body: some View {
        HStack {
            Button(action: {
                withAnimation {
                    viewRouter.currentView = .menu
                }
            }) {
                Image(systemName: "house")
                    .font(.title2)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    showingPlaylist.toggle()
                }
            }) {
                Image(systemName: showingPlaylist ? "list.bullet.circle.fill" : "list.bullet.circle")
                    .font(.title2)
            }
        }
        .buttonStyle(.plain)
        .foregroundColor(.white)
        .padding(8)
        .background(Color.black.opacity(0.3))
    }
}

// Update PlayerView
private struct PlayerView: View {
    @ObservedObject var viewModel: MusicViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Track info
            if let track = viewModel.currentTrack {
                HStack {
                    Text(track.title)
                        .lineLimit(1)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                    
                    if let artist = track.artist {
                        Text("•")
                            .foregroundColor(.green.opacity(0.5))
                        Text(artist)
                            .lineLimit(1)
                            .font(.system(size: 14))
                            .foregroundColor(.green.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            // Timeline
            HStack(spacing: 4) {
                Text(formatTime(viewModel.currentTime))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track background
                        Capsule()
                            .fill(Color.green.opacity(0.2))
                            .frame(height: 6)
                        
                        // Progress
                        Capsule()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(viewModel.currentTime / max(viewModel.duration, 1)), height: 6)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                viewModel.seek(to: percentage)
                            }
                    )
                }
                .frame(height: 24)
                
                Text(formatTime(viewModel.duration))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Controls
            HStack(spacing: 16) {
                // Left controls
                HStack(spacing: 8) {
                    Button(action: viewModel.togglePlayPause) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                    }
                    
                    Button(action: viewModel.playPrevious) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14))
                    }
                    
                    Button(action: viewModel.playNext) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14))
                    }
                    
                    Button(action: viewModel.toggleShuffle) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14))
                            .foregroundColor(viewModel.isShuffleEnabled ? .green : .white.opacity(0.7))
                    }
                    
                    Button(action: viewModel.toggleRepeat) {
                        Image(systemName: viewModel.repeatMode.icon)
                            .font(.system(size: 14))
                            .foregroundColor(viewModel.repeatMode.color)
                    }
                }
                
                Spacer()
                
                // Right controls
                HStack(spacing: 4) {
                    if let track = viewModel.currentTrack {
                        Menu {
                            Button(action: { viewModel.openFile(track.url) }) {
                                Label("Open File", systemImage: "doc")
                            }
                            Button(action: { viewModel.openInFinder(track.url) }) {
                                Label("Show in Finder", systemImage: "folder")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(.green)
                                .frame(width: 24, height: 24)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                    }
                    
                    // Volume control
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .frame(height: 24)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.green.opacity(0.2))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(Color.green)
                                    .frame(width: geometry.size.width * CGFloat(viewModel.volume), height: 6)
                            }
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let percentage = max(0, min(1, value.location.x / geometry.size.width))
                                        viewModel.setVolume(Float(percentage))
                                    }
                            )
                        }
                        .frame(width: 60, height: 24)
                        
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .frame(height: 24)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
            .padding(.horizontal)
            
            // Visualizer
            AudioSpectrumView(fftData: viewModel.fftData)
                .frame(height: 60)
                .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct PlaylistView: View {
    @ObservedObject var viewModel: MusicViewModel
    
    var body: some View {
        List(viewModel.items) { item in
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if let artist = item.artist {
                            Text(artist)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Text(item.fileType.uppercased())
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(3)
                    }
                }
                
                Spacer()
                
                Text(formatTime(item.duration))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .contentShape(Rectangle())
            .listRowBackground(
                viewModel.currentTrack?.id == item.id ?
                Color.green.opacity(0.2) : Color.clear
            )
            .onTapGesture {
                viewModel.playTrack(item)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

private struct KnobControl: View {
    @Binding var value: Float
    let onChange: (Float) -> Void
    @State private var rotation: Double = 0
    @State private var lastRotation: Double = 0
    @State private var isHovering = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: CGFloat(value))
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 12)
                .offset(y: -12)
                .rotationEffect(.degrees(rotation))
            
            if isHovering {
                Text("\(Int(value * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 40, height: 40)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let center = CGPoint(x: 20, y: 20)
                    let angle = atan2(value.location.y - center.y,
                                    value.location.x - center.x)
                    var degrees = angle * 180 / .pi + 90
                    if degrees < 0 { degrees += 360 }
                    
                    let deltaRotation = degrees - lastRotation
                    rotation = min(max(0, rotation + deltaRotation), 360)
                    
                    let normalizedValue = Float(rotation / 360)
                    self.value = normalizedValue
                    onChange(normalizedValue)
                    
                    lastRotation = degrees
                }
                .onEnded { _ in
                    lastRotation = rotation.truncatingRemainder(dividingBy: 360)
                }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct ModernSlider: View {
    let value: Double
    let onChanged: (Double) -> Void
    let width: CGFloat
    let height: CGFloat
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: height/2)
                    .fill(color.opacity(0.2))
                
                // Value track
                RoundedRectangle(cornerRadius: height/2)
                    .fill(color)
                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * value)))
                
                // Handle
                Circle()
                    .fill(Color.white)
                    .frame(width: height * 2, height: height * 2)
                    .shadow(color: .black.opacity(0.2), radius: 2)
                    .position(x: max(height, min(geometry.size.width - height, geometry.size.width * value)), 
                             y: geometry.size.height/2)
            }
        }
        .frame(width: width, height: height)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let width = width - height * 2 // Adjust for handle width
                    let xPos = value.location.x - height // Adjust for handle offset
                    let percentage = max(0, min(1, xPos / width))
                    onChanged(Double(percentage))
                }
        )
    }
}

// Add TimelineScrubber struct
struct TimelineScrubber: View {
    @ObservedObject var viewModel: MusicViewModel
    let width: CGFloat
    @State private var isDragging = false
    @State private var dragPosition: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Base track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green.opacity(0.2))
                
                // Progress track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green)
                    .frame(width: calculateWidth(in: geometry))
                
                // Scrubber handle
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .position(
                        x: calculatePosition(in: geometry),
                        y: geometry.size.height/2
                    )
            }
            .frame(height: 6)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let xPos = value.location.x
                        let width = geometry.size.width
                        dragPosition = min(max(0, xPos), width)
                        let percentage = dragPosition / width
                        viewModel.seek(to: percentage * viewModel.duration)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
    }
    
    private func calculateWidth(in geometry: GeometryProxy) -> CGFloat {
        if isDragging {
            return dragPosition
        } else {
            return geometry.size.width * CGFloat(viewModel.currentTime / max(viewModel.duration, 1))
        }
    }
    
    private func calculatePosition(in geometry: GeometryProxy) -> CGFloat {
        if isDragging {
            return dragPosition
        } else {
            return geometry.size.width * CGFloat(viewModel.currentTime / max(viewModel.duration, 1))
        }
    }
}

#Preview {
    MusicView()
} 
