import SwiftUI
import Cr4sh0utUI
import Cr4sh0utManagers

public struct ContentView: View {
    @StateObject private var viewRouter = ViewRouter.shared
    
    public init() {}
    
    public var body: some View {
        ZStack {
            ReactiveGrid()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            switch viewRouter.currentView {
            case .main:
                MainView()
            case .menu:
                MainMenuView()
            case .about:
                AboutView()
            case .help:
                // Add HelpView when needed
                EmptyView()
            case .photos:
                PhotoView()
            case .music:
                MusicView()
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 800, height: 600)
            .preferredColorScheme(.dark)
    }
}
#endif
