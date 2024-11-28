import SwiftUI
import UniformTypeIdentifiers
import Cr4sh0utUI
import Cr4sh0utManagers

// Model for card information
struct CardInfo: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
}

struct MainMenuView: View {
    @ObservedObject private var viewRouter = ViewRouter.shared
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var mockCards: [CardInfo] {
        [
            CardInfo(title: "Files", icon: "folder.fill", color: .blue) {
                withAnimation {
                    viewRouter.currentView = .main
                }
            },
            CardInfo(title: "Photos", icon: "photo.fill", color: .orange) { print("Photos tapped") },
            CardInfo(title: "Music", icon: "music.note", color: .purple) { print("Music tapped") },
            CardInfo(title: "Settings", icon: "gear", color: .gray) { print("Settings tapped") },
            CardInfo(title: "News", icon: "newspaper.fill", color: .green) { print("News tapped") },
            CardInfo(title: "Weather", icon: "cloud.sun.fill", color: .cyan) { print("Weather tapped") },
            CardInfo(title: "Calendar", icon: "calendar", color: .red) { print("Calendar tapped") },
            CardInfo(title: "Mail", icon: "envelope.fill", color: .indigo) { print("Mail tapped") }
        ]
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.black, Color(white: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                // Grid of cards
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 4),
                        spacing: 20
                    ) {
                        ForEach(mockCards) { card in
                            ViewCard(
                                title: card.title,
                                icon: card.icon,
                                color: card.color,
                                action: card.action
                            )
                        }
                    }
                    .padding(24)
                }
                
                // Bottom bar with time
                HStack {
                    Text(currentTime, formatter: timeFormatter)
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.white)
                        .padding()
                    
                    Spacer()
                }
                .background(Color.black.opacity(0.3))
            }
        }
        .onReceive(timer) { input in
            currentTime = input
        }
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

#Preview {
    MainMenuView()
}