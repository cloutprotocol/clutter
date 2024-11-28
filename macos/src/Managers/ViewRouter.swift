import SwiftUI

public class ViewRouter: ObservableObject {
    public static let shared = ViewRouter()
    
    @Published public var currentView: AppView = .main
    
    private init() {}
    
    public enum AppView {
        case main
        case menu
        case about
        case help
        case photos
        case music
    }
} 