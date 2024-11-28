import SwiftUI
import CoreGraphics
import Foundation

@available(macOS 14.0, *)
struct ReactiveGrid: View {
    let columns: Int
    let rows: Int
    @State private var mouseLocation: CGPoint = .zero
    @State private var hoverLocation: CGPoint = .zero
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    
    init(columns: Int = 12, rows: Int = 12) {
        self.columns = columns
        self.rows = rows
    }
    
    @available(macOS 14.0, *)
    var body: some View {
        GeometryReader { geometry in
            let dotSize: CGFloat = 6
            let spacing = dotSize * 3
            
            let columnsNeeded = Int(ceil(geometry.size.width / spacing))
            let rowsNeeded = Int(ceil(geometry.size.height / spacing))
            
            ZStack {
                Color.black.opacity(0.01)
                
                ForEach(0..<rowsNeeded, id: \.self) { row in
                    ForEach(0..<columnsNeeded, id: \.self) { col in
                        Circle()
                            .fill(.white)
                            .frame(width: dotSize, height: dotSize)
                            .position(
                                x: spacing * CGFloat(col),
                                y: spacing * CGFloat(row)
                            )
                            .opacity(combinedOpacity(
                                for: CGPoint(
                                    x: spacing * CGFloat(col),
                                    y: spacing * CGFloat(row)
                                ),
                                hoverLocation: hoverLocation,
                                clickLocation: mouseLocation
                            ))
                            .animation(.easeOut(duration: 0.2), value: mouseLocation)
                            .animation(.easeOut(duration: 0.1), value: hoverLocation)
                    }
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovering = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        hoverLocation = value.location
                        mouseLocation = value.location
                        isDragging = true
                    }
                    .onEnded { _ in
                        isDragging = false
                        mouseLocation = .zero
                    }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverLocation = location
                case .ended:
                    hoverLocation = .zero
                }
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func combinedOpacity(for position: CGPoint, hoverLocation: CGPoint, clickLocation: CGPoint) -> Double {
        let baseOpacity = 0.25
        var finalOpacity = baseOpacity
        
        // Hover effect
        if hoverLocation != .zero {
            let hoverDistance = sqrt(
                pow(position.x - hoverLocation.x, 2) +
                pow(position.y - hoverLocation.y, 2)
            )
            
            let hoverMaxDistance: CGFloat = 80
            let hoverNormalizedDistance = hoverDistance / hoverMaxDistance
            let hoverFalloff = 1.0 - min(hoverNormalizedDistance, 1.0)
            finalOpacity += hoverFalloff * 0.3
        }
        
        // Click ripple effect
        if isDragging && clickLocation != .zero {
            let rippleDistance = sqrt(
                pow(position.x - clickLocation.x, 2) +
                pow(position.y - clickLocation.y, 2)
            )
            
            let rippleMaxDistance: CGFloat = 60
            let rippleNormalizedDistance = rippleDistance / rippleMaxDistance
            
            let ripple = sin(rippleNormalizedDistance * .pi * 3) * 0.5 + 0.5
            let rippleFalloff = pow(1.0 - min(rippleNormalizedDistance, 1.0), 2)
            
            finalOpacity += (ripple * rippleFalloff * 1)
        }
        
        return min(finalOpacity, 1.0)
    }
}