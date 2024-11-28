import SwiftUI
import CoreGraphics
import Foundation

public struct ReactiveGrid: View {
    @State private var mouseLocation: CGPoint = .zero
    @State private var isDragging: Bool = false
    
    // Fixed spacing between dots
    private let spacing: CGFloat = 16
    private let dotSize: CGFloat = 2
    private let padding: CGFloat = 2
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            // Calculate number of dots based on available space
            let columns = Int(geometry.size.width / spacing)
            let rows = Int(geometry.size.height / spacing)
            
            // Center the grid
            let totalWidth = spacing * CGFloat(columns - 1)
            let totalHeight = spacing * CGFloat(rows - 1)
            let offsetX = (geometry.size.width - totalWidth) / 2
            let offsetY = (geometry.size.height - totalHeight) / 2
            
            ZStack {
                Color.black
                
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<columns, id: \.self) { col in
                        Circle()
                            .fill(.white)
                            .frame(width: dotSize, height: dotSize)
                            .position(
                                x: offsetX + spacing * CGFloat(col),
                                y: offsetY + spacing * CGFloat(row)
                            )
                            .opacity(opacity(
                                for: CGPoint(
                                    x: offsetX + spacing * CGFloat(col),
                                    y: offsetY + spacing * CGFloat(row)
                                ),
                                mouseLocation: mouseLocation
                            ))
                            .animation(.easeOut(duration: 0.2), value: mouseLocation)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        mouseLocation = value.location
                        isDragging = true
                    }
                    .onEnded { _ in
                        withAnimation(.easeOut(duration: 0.5)) {
                            isDragging = false
                            mouseLocation = .zero
                        }
                    }
            )
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.5)) {
                    isDragging = hovering
                    if !hovering {
                        mouseLocation = .zero
                    }
                }
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func opacity(for position: CGPoint, mouseLocation: CGPoint) -> Double {
        guard isDragging && mouseLocation != .zero else { return 0.3 }
        
        let distance = sqrt(
            pow(position.x - mouseLocation.x, 2) +
            pow(position.y - mouseLocation.y, 2)
        )
        
        let maxDistance: CGFloat = 100
        let normalizedDistance = distance / maxDistance
        
        // Create ripple effect
        let ripple = sin(normalizedDistance * .pi * 2) * 0.5 + 0.5
        let falloff = 1.0 - min(normalizedDistance, 1.0)
        
        let opacity = ripple * falloff * 0.9 + 0.3
        return opacity
    }
}

#Preview {
    ReactiveGrid()
        .frame(width: 400, height: 300)
        .preferredColorScheme(.dark)
}
