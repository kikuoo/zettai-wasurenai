import Foundation
import AVFoundation

/// 音声でやること・リマインダーを読み上げるマネージャー
public final class SpeechManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = SpeechManager()
    
    @Published public private(set) var isSpeaking: Bool = false
    private let synthesizer = AVSpeechSynthesizer()
    private var repeatTimer: Timer?
    private var currentTextToRepeat: String?
    
    private override init() {
        super.init()
        synthesizer.delegate = self
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioSession setup error: \(error)")
        }
    }
    
    /// 1回読み上げる
    public func speak(text: String, rate: Float = 0.52, pitch: Float = 1.05) {
        stop()
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = 1.0
        
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    /// 激しくお知らせモード用：停止されるまで繰り返しアナウンス
    public func startRepeatingSpeech(taskTitle: String, interval: TimeInterval = 4.0) {
        stop()
        
        let announceText = "絶対に忘れないでください！ \(taskTitle) の時間です！"
        currentTextToRepeat = announceText
        
        // 初回即時発声
        speak(text: announceText)
        
        // インターバルで繰り返し発声
        repeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, let text = self.currentTextToRepeat else { return }
            if !self.synthesizer.isSpeaking {
                let utterance = AVSpeechUtterance(string: text)
                utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
                utterance.rate = 0.53
                utterance.pitchMultiplier = 1.1
                utterance.volume = 1.0
                self.synthesizer.speak(utterance)
            }
        }
    }
    
    /// 読み上げを停止する
    public func stop() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        currentTextToRepeat = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
    
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if repeatTimer == nil {
            isSpeaking = false
        }
    }
}
