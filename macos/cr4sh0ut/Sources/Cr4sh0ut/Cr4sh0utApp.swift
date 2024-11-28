import SwiftUI
import AppKit

@main
@available(macOS 14.0, *)
struct Cr4sh0utApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showSettings = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 300)
                .preferredColorScheme(.dark)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "gear")
                                .symbolRenderingMode(.hierarchical)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(.borderless)
                        .help("Settings")
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .systemServices) {}
            CommandGroup(replacing: .help) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bring app to front and activate
        NSApp.activate(ignoringOtherApps: true)
        
        // Set up menu bar
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
        
        // Ensure window is visible and front-most
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.windows.first {
                window.level = .floating
                window.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        if let window = NSApp.windows.first {
            window.level = .floating
            window.orderFrontRegardless()
        }
    }
} 