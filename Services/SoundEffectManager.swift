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
    @Published public private(set) var previewingSoundType: AlarmSoundType? = nil
    
    // 現在選択されているアラーム音
    @Published public var selectedSoundType: AlarmSoundType {
        didSet {
            UserDefaults.standard.set(selectedSoundType.rawValue, forKey: "SelectedAlarmSoundType_v1")
            prepareAudioPlayer(for: selectedSoundType)
        }
    }
    
    // カスタム音楽のタイトル
    @Published public var customMusicTitle: String? {
        didSet {
            UserDefaults.standard.set(customMusicTitle, forKey: "CustomMusicTitle_v1")
        }
    }
    
    private var alarmTimer: Timer?
    private var hapticTimer: Timer?
    private var previewTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var previewPlayer: AVAudioPlayer?
    
    private let customMusicFileName = "custom_alarm_music.m4a"
    
    private init() {
        let savedRaw = UserDefaults.standard.string(forKey: "SelectedAlarmSoundType_v1") ?? AlarmSoundType.intenseSiren.rawValue
        self.selectedSoundType = AlarmSoundType(rawValue: savedRaw) ?? .intenseSiren
        self.customMusicTitle = UserDefaults.standard.string(forKey: "CustomMusicTitle_v1")
        
        prepareAudioPlayer(for: self.selectedSoundType)
    }
    
    // MARK: - カスタム音楽の保存・取得・削除
    
    public var customMusicFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(customMusicFileName)
    }
    
    public var hasCustomMusic: Bool {
        return FileManager.default.fileExists(atPath: customMusicFileURL.path)
    }
    
    /// 外部ファイルまたはミュージックからカスタム音源をDocumentsへコピー保存
    public func saveCustomMusic(from sourceURL: URL, displayName: String) -> Bool {
        let shouldStopSecurityScoped = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let destinationURL = customMusicFileURL
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            
            DispatchQueue.main.async {
                self.customMusicTitle = displayName
                self.selectedSoundType = .customMusic
            }
            return true
        } catch {
            print("Failed to save custom music: \(error)")
            return false
        }
    }
    
    /// カスタム音源を削除
    public func removeCustomMusic() {
        if FileManager.default.fileExists(atPath: customMusicFileURL.path) {
            try? FileManager.default.removeItem(at: customMusicFileURL)
        }
        customMusicTitle = nil
        selectedSoundType = .intenseSiren
    }
    
    // MARK: - プレイヤーの準備
    
    public func prepareAudioPlayer(for type: AlarmSoundType) {
        audioPlayer?.stop()
        audioPlayer = nil
        
        switch type {
        case .intenseSiren:
            if let soundURL = Bundle.main.url(forResource: "alarm_siren", withExtension: "caf") {
                audioPlayer = try? AVAudioPlayer(contentsOf: soundURL)
            }
            if audioPlayer == nil {
                audioPlayer = makeSynthesizedPlayer(type: .intenseSiren)
            }
            
        case .digitalBeep:
            audioPlayer = makeSynthesizedPlayer(type: .digitalBeep)
            
        case .warningBell:
            audioPlayer = makeSynthesizedPlayer(type: .warningBell)
            
        case .customMusic:
            if hasCustomMusic {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: customMusicFileURL)
                } catch {
                    print("Failed to load custom music, falling back to siren: \(error)")
                    audioPlayer = makeSynthesizedPlayer(type: .intenseSiren)
                }
            } else {
                audioPlayer = makeSynthesizedPlayer(type: .intenseSiren)
            }
        }
        
        audioPlayer?.numberOfLoops = -1
        audioPlayer?.volume = 1.0
        audioPlayer?.prepareToPlay()
    }
    
    // MARK: - 合成オーディオプレイヤーの生成
    
    private func makeSynthesizedPlayer(type: AlarmSoundType) -> AVAudioPlayer? {
        let sampleRate: Double = 44100.0
        var samples = [Int16]()
        
        switch type {
        case .intenseSiren:
            // 950Hz ↔ 1300Hz の高周波往復サイレン
            let duration: Double = 0.8
            let numSamples = Int(sampleRate * duration)
            samples.reserveCapacity(numSamples)
            for i in 0..<numSamples {
                let t = Double(i) / sampleRate
                let freq = (sin(2.0 * .pi * 4.0 * t) > 0) ? 950.0 : 1300.0
                let value = sin(2.0 * .pi * freq * t) * 0.95
                samples.append(Int16(value * Double(Int16.max)))
            }
            
        case .digitalBeep:
            // ピピピ！ピピピ！の緊急デジタルビープ（2200Hz）
            let duration: Double = 0.55
            let numSamples = Int(sampleRate * duration)
            samples.reserveCapacity(numSamples)
            for i in 0..<numSamples {
                let t = Double(i) / sampleRate
                // 3連打: 0~0.07s, 0.11~0.18s, 0.22~0.29s でON
                let isOn = (t >= 0.0 && t < 0.07) || (t >= 0.11 && t < 0.18) || (t >= 0.22 && t < 0.29)
                if isOn {
                    let value = sin(2.0 * .pi * 2200.0 * t) * 0.95
                    samples.append(Int16(value * Double(Int16.max)))
                } else {
                    samples.append(0)
                }
            }
            
        case .warningBell:
            // 鐘・消防ベル風の金属打音（720Hz基音 + 1440Hz/2160Hz倍音の高速減衰パルス）
            let duration: Double = 0.45
            let numSamples = Int(sampleRate * duration)
            samples.reserveCapacity(numSamples)
            for i in 0..<numSamples {
                let t = Double(i) / sampleRate
                let decay = exp(-7.5 * t)
                let base = sin(2.0 * .pi * 720.0 * t)
                let h1 = sin(2.0 * .pi * 1440.0 * t) * 0.5
                let h2 = sin(2.0 * .pi * 2160.0 * t) * 0.25
                let value = (base + h1 + h2) * decay * 0.95
                samples.append(Int16(value * Double(Int16.max)))
            }
            
        case .customMusic:
            return nil
        }
        
        let data = Data(bytes: samples, count: samples.count * MemoryLayout<Int16>.size)
        let audioFormat = AudioStreamBasicDescription(
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
        let wavData = createWavHeader(dataSize: data.count, format: audioFormat) + data
        return try? AVAudioPlayer(data: wavData)
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
    
    // MARK: - 試聴（プレビュー）再生
    
    /// サウンドの試聴（5秒後に自動停止、または再タップで停止）
    public func previewSound(type: AlarmSoundType) {
        if previewingSoundType == type {
            stopPreview()
            return
        }
        
        stopPreview()
        stopAlarm()
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Preview audio session error: \(error)")
        }
        
        var playerToPreview: AVAudioPlayer?
        if type == .customMusic {
            if hasCustomMusic {
                playerToPreview = try? AVAudioPlayer(contentsOf: customMusicFileURL)
            } else {
                playerToPreview = makeSynthesizedPlayer(type: .intenseSiren)
            }
        } else {
            if type == .intenseSiren, let soundURL = Bundle.main.url(forResource: "alarm_siren", withExtension: "caf") {
                playerToPreview = try? AVAudioPlayer(contentsOf: soundURL)
            }
            if playerToPreview == nil {
                playerToPreview = makeSynthesizedPlayer(type: type)
            }
        }
        
        guard let p = playerToPreview else { return }
        p.numberOfLoops = -1
        p.volume = 1.0
        p.play()
        
        self.previewPlayer = p
        self.previewingSoundType = type
        
        // 5秒後に自動停止
        previewTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.stopPreview()
        }
    }
    
    public func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        previewPlayer?.stop()
        previewPlayer = nil
        previewingSoundType = nil
    }
    
    // MARK: - アラーム本番再生
    
    /// 激しいアラーム音とバイブレーションを開始
    public func startIntenseAlarm() {
        stopAlarm()
        stopPreview()
        isAlarmPlaying = true
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
        
        prepareAudioPlayer(for: selectedSoundType)
        
        if let player = audioPlayer {
            player.currentTime = 0
            player.play()
        } else {
            // フォールバック
            alarmTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
                AudioServicesPlaySystemSound(1005)
            }
        }
        
        #if canImport(UIKit)
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
