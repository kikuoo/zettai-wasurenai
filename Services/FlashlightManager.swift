import Foundation
import AVFoundation

#if canImport(UIKit)
import UIKit
#endif

/// iPhoneのカメラフラッシュ（トーチ）をストロボ点滅させるマネージャー
public final class FlashlightManager: ObservableObject {
    public static let shared = FlashlightManager()
    
    @Published public private(set) var isFlashing: Bool = false
    private var flashTimer: Timer?
    private var torchState: Bool = false
    
    private init() {}
    
    /// ストロボ点滅を開始する
    public func startStrobeFlash(interval: TimeInterval = 0.18) {
        stopStrobeFlash()
        
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else {
            // シミュレータまたはトーチ非対応端末
            isFlashing = true
            return
        }
        
        isFlashing = true
        flashTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.toggleTorch(device: device)
        }
    }
    
    /// 点滅を停止する
    public func stopStrobeFlash() {
        flashTimer?.invalidate()
        flashTimer = nil
        isFlashing = false
        torchState = false
        
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        } catch {
            print("Failed to turn off torch: \(error)")
        }
    }
    
    private func toggleTorch(device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            torchState.toggle()
            if torchState {
                try device.setTorchModeOn(level: 1.0)
            } else {
                device.torchMode = .off
            }
            device.unlockForConfiguration()
        } catch {
            // エラー時は何もしない
        }
    }
}
