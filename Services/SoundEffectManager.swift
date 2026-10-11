import Foundation
import AudioToolbox
import AVFoundation

#if canImport(UIKit)
import UIKit
#endif

/// アラーム音とバイブレーション（触覚）を激しく鳴らすマネージャー
public final class SoundEffectManager: ObservableObject {
    public static let shared = SoundEffectManager()
    
    @Published public private(set) var isAlarmPlaying: Bool = false
    private var alarmTimer: Timer?
    private var hapticTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        prepareAudioPlayer()
    }
    
    /// オーディオプレイヤーの準備（バンドル内のサイレン音声、または高周波ビープ音を生成）
    private func prepareAudioPlayer() {
        if let soundURL = Bundle.main.url(forResource: "alarm_siren", withExtension: "caf") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.numberOfLoops = -1 // 無限ループ
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                return
            } catch {
                print("Failed to load bundled alarm_siren.caf: \(error)")
            }
        }
        
        let sampleRate: Double = 44100.0
        let duration: Double = 0.8
        let numSamples = Int(sampleRate * duration)
        var samples = [Int16]()
        samples.reserveCapacity(numSamples)
        
        // 2周波数の警報音（880Hzと1200Hzを往復する鋭いアラーム）
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let freq = (sin(2.0 * .pi * 4.0 * t) > 0) ? 950.0 : 1300.0
            let value = sin(2.0 * .pi * freq * t) * 0.9
            samples.append(Int16(value * Double(Int16.max)))
        }
        
        let data = Data(bytes: samples, count: samples.count * MemoryLayout<Int16>.size)
        
        var audioFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        
        // WAVヘッダ構築
        let wavData = createWavHeader(dataSize: data.count, format: audioFormat) + data
        
        do {
            audioPlayer = try AVAudioPlayer(data: wavData)
            audioPlayer?.numberOfLoops = -1 // 無限ループ
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to initialize AVAudioPlayer: \(error)")
        }
    }
    
    private func createWavHeader(dataSize: Int, format: AudioStreamBasicDescription) -> Data {
        var header = Data()
        header.append(contentsOf: "RIFF".utf8)
        var chunkSize = UInt32(dataSize + 36)
        header.append(Data(bytes: &chunkSize, count: 4))
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        var subchunk1Size = UInt32(16)
        header.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat = UInt16(1)
        header.append(Data(bytes: &audioFormat, count: 2))
        var numChannels = UInt16(format.mChannelsPerFrame)
        header.append(Data(bytes: &numChannels, count: 2))
        var sampleRate = UInt32(format.mSampleRate)
        header.append(Data(bytes: &sampleRate, count: 4))
        var byteRate = UInt32(format.mSampleRate * Double(format.mBytesPerFrame))
        header.append(Data(bytes: &byteRate, count: 4))
        var blockAlign = UInt16(format.mBytesPerFrame)
        header.append(Data(bytes: &blockAlign, count: 2))
        var bitsPerSample = UInt16(format.mBitsPerChannel)
        header.append(Data(bytes: &bitsPerSample, count: 2))
        header.append(contentsOf: "data".utf8)
        var dataLength = UInt32(dataSize)
        header.append(Data(bytes: &dataLength, count: 4))
        return header
    }
    
    /// 激しいアラーム音とバイブレーションを開始
    public func startIntenseAlarm() {
        stopAlarm()
        isAlarmPlaying = true
        
        // システムオーディオセッションを最大音量で割り込み可能に設定
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        
        // 自作サイレントーンの再生
        if let player = audioPlayer {
            player.currentTime = 0
            player.play()
        } else {
            // フォールバック: システムサウンドを定期再生
            alarmTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
                AudioServicesPlaySystemSound(1005) // SMS alert / siren style
            }
        }
        
        #if canImport(UIKit)
        // 激しい触覚フィードバック（バイブレーション）の連続実行
        hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        #endif
    }
    
    /// アラーム音とバイブレーションを停止
    public func stopAlarm() {
        alarmTimer?.invalidate()
        alarmTimer = nil
        
        hapticTimer?.invalidate()
        hapticTimer = nil
        
        audioPlayer?.stop()
        isAlarmPlaying = false
    }
    
    /// 単発の確認用サウンド
    public func playSuccessSound() {
        AudioServicesPlaySystemSound(1001)
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}
