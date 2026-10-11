import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 3秒間長押しすることで誤操作を防ぎ確実に解除するボタン
public struct LongPressButtonView: View {
    public let title: String
    public let duration: Double
    public let onCompleted: () -> Void
    
    @State private var isPressing: Bool = false
    @State private var progress: CGFloat = 0.0
    @State private var timer: Timer?
    
    public init(title: String = "3秒長押しで完了", duration: Double = 2.5, onCompleted: @escaping () -> Void) {
        self.title = title
        self.duration = duration
        self.onCompleted = onCompleted
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // 背景ボタン
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    )
                
                // 進行バー
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .fill(Color.green)
                        .frame(width: geo.size.width * progress, height: 64)
                }
                .mask(RoundedRectangle(cornerRadius: 36, style: .continuous))
                
                // テキストとアイコン
                HStack(spacing: 12) {
                    Image(systemName: progress >= 1.0 ? "checkmark.circle.fill" : "hand.tap.fill")
                        .font(.system(size: 22, weight: .bold))
                    
                    Text(progress >= 1.0 ? "解除完了！" : (isPressing ? "指を離さずキープ..." : title))
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundColor(.white)
            }
            .frame(height: 64)
            .scaleEffect(isPressing ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressing)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressing {
                            startPress()
                        }
                    }
                    .onEnded { _ in
                        cancelPress()
                    }
            )
        }
    }
    
    private func startPress() {
        isPressing = true
        progress = 0.0
        
        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        #endif
        
        let interval: Double = 0.05
        let step = CGFloat(interval / duration)
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            progress += step
            if progress >= 1.0 {
                progress = 1.0
                timer?.invalidate()
                timer = nil
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onCompleted()
                }
            }
        }
    }
    
    private func cancelPress() {
        if progress < 1.0 {
            timer?.invalidate()
            timer = nil
            isPressing = false
            withAnimation(.easeOut(duration: 0.2)) {
                progress = 0.0
            }
        }
    }
}
