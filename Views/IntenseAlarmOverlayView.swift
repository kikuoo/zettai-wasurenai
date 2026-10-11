import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// とにかく激しくお知らせするフルスクリーンアラームビュー
public struct IntenseAlarmOverlayView: View {
    public let item: ReminderItem
    public let onDismiss: (Bool) -> Void // Bool: 完了にするかどうか
    
    @State private var flashPhase: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var dismissMethod: Int = 0 // 0: スライダー, 1: 長押し
    
    public init(item: ReminderItem, onDismiss: @escaping (Bool) -> Void) {
        self.item = item
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // 背景点滅ストロボ（赤と暗赤色・黄色を高速点滅）
            (flashPhase ? Color(red: 0.9, green: 0.1, blue: 0.1) : Color(red: 0.25, green: 0.05, blue: 0.05))
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.28).repeatForever(autoreverses: true), value: flashPhase)
            
            VStack(spacing: 24) {
                // ヘッダー警告
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.yellow)
                    
                    Text("絶対に忘れない！警報")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.yellow)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // メインのアラームアイコン（脈動アニメーション）
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: item.category.iconName)
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(item.category.color)
                }
                .padding(.vertical, 10)
                
                // タスクタイトル（超大文字）
                VStack(spacing: 12) {
                    Text(item.title)
                        .font(.system(size: 34, weight: .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Text("今すぐ実行してください！")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.yellow)
                }
                
                // アラーム発動中ステータスバッジ
                HStack(spacing: 16) {
                    if item.isLightAlert {
                        Label("ライト点滅中", systemImage: "flashlight.on.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.orange.opacity(0.8)))
                    }
                    
                    if item.isVoiceAlert {
                        Label("音声読み上げ中", systemImage: "speaker.wave.3.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.purple.opacity(0.8)))
                    }
                    
                    Label("激震サイレン", systemImage: "bell.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.red.opacity(0.8)))
                }
                
                Spacer()
                
                // 解除方法切り替えセグメント
                Picker("解除方法", selection: $dismissMethod) {
                    Text("スライドで解除").tag(0)
                    Text("長押しで解除").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 32)
                
                // 停止エリア（誤操作防止）
                VStack(spacing: 16) {
                    if dismissMethod == 0 {
                        SlideToUnlockView(title: "スライドして「完了」にして停止") {
                            onDismiss(true)
                        }
                        .padding(.horizontal, 28)
                    } else {
                        LongPressButtonView(title: "3秒長押しで「完了」にして停止", duration: 2.5) {
                            onDismiss(true)
                        }
                        .padding(.horizontal, 28)
                    }
                    
                    // 5分後スヌーズ（後でもう一度激震）
                    Button(action: {
                        #if canImport(UIKit)
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        #endif
                        onDismiss(false) // 完了にはせず停止（スヌーズ）
                    }) {
                        Text("あとで (5分後にまた激しく知らせる)")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .underline()
                            .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 36)
            }
        }
        .onAppear {
            flashPhase = true
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulseScale = 1.25
            }
        }
    }
}
