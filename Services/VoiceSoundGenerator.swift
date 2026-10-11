import Foundation
import AVFoundation

/// 「○○の時間です」という音声読み上げ＋サイレンを1つの音声ファイル(.caf)に書き出し、
/// 通知サウンドとして使えるよう <App>/Library/Sounds に保存するクラス。
/// → アプリを開いていなくても（ロック中・他アプリ使用中でも）通知と同時に声で読み上げられます。
/// ※iOSの通知サウンドは最大30秒までです。
public final class VoiceSoundGenerator {
    public static let shared = VoiceSoundGenerator()
    
    private var activeSynths: [UUID: AVSpeechSynthesizer] = [:]
    private let lock = NSLock()
    private static let maxDuration: Double = 28.0
    
    private init() {}
    
    public static var soundsDirectory: URL {
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return lib.appendingPathComponent("Sounds", isDirectory: true)
    }
    
    public func soundName(for id: UUID) -> String {
        "voice_\(id.uuidString).caf"
    }
    
    public func removeSound(for id: UUID) {
        let url = Self.soundsDirectory.appendingPathComponent(soundName(for: id))
        try? FileManager.default.removeItem(at: url)
    }
    
    /// 音声ファイルを生成。完了時にメインスレッドでサウンド名（失敗時はnil）を返す
    public func generate(for item: ReminderItem, completion: @escaping (String?) -> Void) {
        let dir = Self.soundsDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = soundName(for: item.id)
        let url = dir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        
        let text = "\(item.title)の時間です。絶対に忘れないでください。もう一度言います。\(item.title)の時間です。"
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.rate = 0.48
        utterance.volume = 1.0
        
        let synth = AVSpeechSynthesizer()
        lock.lock(); activeSynths[item.id] = synth; lock.unlock()
        
        let state = WriteState()
        let itemId = item.id
        
        let finish: () -> Void = { [weak self] in
            guard state.markDone() else { return }
            var success = false
            if let file = state.file {
                // 残り時間をサイレンで埋める（最大28秒）
                let sr = file.processingFormat.sampleRate
                let elapsed = Double(file.length) / sr
                let remain = max(0, min(10.0, Self.maxDuration - elapsed))
                if remain > 0.5, let siren = Self.makeSiren(format: file.processingFormat, seconds: remain) {
                    try? file.write(from: siren)
                }
                success = file.length > 0
            }
            state.file = nil // ファイルを閉じる
            self?.lock.lock(); self?.activeSynths[itemId] = nil; self?.lock.unlock()
            DispatchQueue.main.async { completion(success ? name : nil) }
        }
        
        synth.write(utterance) { buffer in
            guard let pcm = buffer as? AVAudioPCMBuffer else { return }
            if pcm.frameLength == 0 {
                finish()
                return
            }
            do {
                if state.file == nil {
                    let f = try AVAudioFile(
                        forWriting: url,
                        settings: pcm.format.settings,
                        commonFormat: pcm.format.commonFormat,
                        interleaved: pcm.format.isInterleaved
                    )
                    // 冒頭に2秒のサイレン
                    if let siren = Self.makeSiren(format: pcm.format, seconds: 2.0) {
                        try f.write(from: siren)
                    }
                    state.file = f
                }
                try state.file?.write(from: pcm)
            } catch {
                print("Voice sound write error: \(error)")
            }
        }
        
        // 終了通知が来ない場合の保険（8秒でタイムアウト）
        DispatchQueue.global().asyncAfter(deadline: .now() + 8.0) { finish() }
    }
    
    /// 指定フォーマットで鋭い2トーンのサイレン音を生成
    private static func makeSiren(format: AVAudioFormat, seconds: Double) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let frames = AVAudioFrameCount(sr * seconds)
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        let channels = Int(format.channelCount)
        
        func sample(_ i: Int) -> Double {
            let t = Double(i) / sr
            let freq = (sin(2.0 * .pi * 3.0 * t) > 0) ? 950.0 : 1300.0
            return sin(2.0 * .pi * freq * t) * 0.85
        }
        
        switch format.commonFormat {
        case .pcmFormatFloat32:
            guard let data = buf.floatChannelData else { return nil }
            for ch in 0..<channels {
                for i in 0..<Int(frames) { data[ch][i] = Float(sample(i)) }
            }
        case .pcmFormatInt16:
            guard let data = buf.int16ChannelData else { return nil }
            for ch in 0..<channels {
                for i in 0..<Int(frames) { data[ch][i] = Int16(sample(i) * Double(Int16.max)) }
            }
        case .pcmFormatInt32:
            guard let data = buf.int32ChannelData else { return nil }
            for ch in 0..<channels {
                for i in 0..<Int(frames) { data[ch][i] = Int32(sample(i) * Double(Int32.max)) }
            }
        default:
            return nil
        }
        return buf
    }
}

/// 書き込み状態（コールバック間で共有）
private final class WriteState {
    var file: AVAudioFile?
    private var done = false
    private let lock = NSLock()
    
    /// 初回のみtrueを返す
    func markDone() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}
