import Foundation

/// アラーム音の種類
public enum AlarmSoundType: String, CaseIterable, Identifiable, Codable {
    case intenseSiren = "siren"      // 激サイレン（緊急警報風）
    case digitalBeep  = "digital"    // 電子アラーム（デジタルピピピ音）
    case warningBell  = "bell"       // 警告ベル（連続ベル音）
    case customMusic  = "custom"     // お気に入りの音楽（プレミアム限定）
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .intenseSiren:
            return "激サイレン（緊急警報）"
        case .digitalBeep:
            return "電子アラーム（ピピピ連打）"
        case .warningBell:
            return "警告ベル（連続ベル音）"
        case .customMusic:
            return "お気に入りの音楽（カスタムBGM）"
        }
    }
    
    public var description: String {
        switch self {
        case .intenseSiren:
            return "高周波と鋭い往復音で絶対に起きる標準の強烈サイレン"
        case .digitalBeep:
            return "電子音の高速ビープ音で危機感を煽るアラーム"
        case .warningBell:
            return "消防ベルや鐘のような力強いパルス警報音"
        case .customMusic:
            return "お気に入りの楽曲や推しのボイスを設定可能（プレミアム限定）"
        }
    }
    
    public var iconName: String {
        switch self {
        case .intenseSiren:
            return "light.beacon.max.fill"
        case .digitalBeep:
            return "waveform.path.ecg"
        case .warningBell:
            return "bell.and.waves.left.and.right.fill"
        case .customMusic:
            return "music.note.list"
        }
    }
    
    /// プレミアム会員限定かどうか
    public var isProOnly: Bool {
        return self == .customMusic
    }
}
