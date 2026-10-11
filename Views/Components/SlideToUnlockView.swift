import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// アラーム停止用のスライダーコンポーネント（誤操作防止）
public struct SlideToUnlockView: View {
    public let title: String
    public let onUnlocked: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isUnlocked: Bool = false
    
    public init(title: String = "スライドして停止", onUnlocked: @escaping () -> Void) {
        self.title = title
        self.onUnlocked = onUnlocked
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let sliderWidth = geometry.size.width
            let knobSize: CGFloat = 64
            let maxOffset = sliderWidth - knobSize - 8
            
            ZStack(alignment: .leading) {
                // 背景トラック
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    )
                
                // プログレス背景
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color.green.opacity(0.6))
                    .frame(width: max(knobSize + 8, dragOffset + knobSize + 4), height: 72)
                
                // ガイドテキスト
                HStack {
                    Spacer()
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(Double(1.0 - (dragOffset / maxOffset)))
                    Spacer()
                }
                
                // つまみ（スライダーノブ）
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: knobSize, height: knobSize)
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                    
                    Image(systemName: isUnlocked ? "checkmark" : "chevron.right.2")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(isUnlocked ? .green : .red)
                }
                .offset(x: dragOffset + 4)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            guard !isUnlocked else { return }
                            let translation = value.translation.width
                            if translation > 0 {
                                dragOffset = min(translation, maxOffset)
                            }
                        }
                        .onEnded { value in
                            guard !isUnlocked else { return }
                            if dragOffset >= maxOffset * 0.85 {
                                withAnimation(.spring()) {
                                    dragOffset = maxOffset
                                    isUnlocked = true
                                }
                                #if canImport(UIKit)
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                #endif
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onUnlocked()
                                }
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
            }
        }
        .frame(height: 72)
    }
}
