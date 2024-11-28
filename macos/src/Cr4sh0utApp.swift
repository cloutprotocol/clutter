import SwiftUI
import Cr4sh0utUI
import Cr4sh0utViews
import Cr4sh0utManagers

@main
struct Cr4sh0utApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = NSHostingView(rootView: ContentView())
        window.level = .floating
        window.collectionBehavior = .canJoinAllSpaces
        window.makeKeyAndOrderFront(nil)
        window.center()
        window.title = "cr4sh0ut"
        
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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