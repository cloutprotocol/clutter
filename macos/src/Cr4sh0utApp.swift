import SwiftUI
import Cr4sh0utUI
import Cr4sh0utViews
import Cr4sh0utManagers

@main
struct Cr4sh0utApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

#if PREVIEW
#Preview("Cr4sh0ut") {
    ContentView()
        .frame(width: 800, height: 600)
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
}
#endif