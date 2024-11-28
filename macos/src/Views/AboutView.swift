import SwiftUI
import Cr4sh0utUI
import Cr4sh0utManagers

public struct AboutView: View {
    @ObservedObject private var viewRouter = ViewRouter.shared
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 60))
                .foregroundColor(.white)
            
            VStack(spacing: 4) {
                Text("cr4sh0ut")
                    .font(.title)
                Text("v1.11")
                    .font(.headline)
                Text("all rights reserved.")
                    .font(.subheadline)
            }
            .foregroundColor(.white)
            
            Button("Back") {
                viewRouter.currentView = .main
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#if DEBUG
struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView()
            .frame(width: 800, height: 600)
            .preferredColorScheme(.dark)
            .background(Color.black)
    }
}
#endif 