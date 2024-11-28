import SwiftUI

public struct ViewCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false
    
    public init(title: String, icon: String, color: Color, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    color.opacity(isHovered ? 0.9 : 0.7),
                                    color.opacity(isHovered ? 0.7 : 0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: color.opacity(0.3), radius: isHovered ? 10 : 5)
                    
                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                .frame(height: 120)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ViewCard(
            title: "Files",
            icon: "folder",
            color: .blue
        ) {
            print("Tapped")
        }
    }
}