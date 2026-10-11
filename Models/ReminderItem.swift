import Foundation

public struct ReminderItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var category: ReminderCategory
    public var targetDate: Date
    public var repeatOption: RepeatOption
    public var isGekiMode: Bool           // とにかく激しくお知らせするモード
    public var isVoiceAlert: Bool         // 音声で読み上げる機能
    public var isLightAlert: Bool         // 光（画面＋カメラフラッシュ）でお知らせ
    public var isCompleted: Bool
    public var createdAt: Date
    public var locationTarget: LocationTarget?   // 場所によるリマインダー設定
    
    public init(
        id: UUID = UUID(),
        title: String,
        category: ReminderCategory = .general,
        targetDate: Date,
        repeatOption: RepeatOption = .none,
        isGekiMode: Bool = true,
        isVoiceAlert: Bool = true,
        isLightAlert: Bool = true,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        locationTarget: LocationTarget? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.targetDate = targetDate
        self.repeatOption = repeatOption
        self.isGekiMode = isGekiMode
        self.isVoiceAlert = isVoiceAlert
        self.isLightAlert = isLightAlert
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.locationTarget = locationTarget
    }
    
    /// 予定時刻を過ぎているかどうか
    public var isOverdue: Bool {
        // 地図・場所指定の場合は時間超過判定を行わない
        if locationTarget != nil {
            return false
        }
        return !isCompleted && targetDate < Date()
    }
    
    /// 老若男女にわかりやすい残り時間・トリガー表現
    public var formattedRemainingTime: String {
        if isCompleted {
            return "完了済み"
        }
        
        // 地図・場所指定の場合は場所の到着/出発トリガーを表示
        if let loc = locationTarget {
            if loc.notifyOnEntry && loc.notifyOnExit {
                return "到着・出発時"
            } else if loc.notifyOnEntry {
                return "到着時に通知"
            } else if loc.notifyOnExit {
                return "出発時に通知"
            }
            return "場所連動"
        }
        
        let diff = targetDate.timeIntervalSince(Date())
        if diff < 0 {
            let overdueMinutes = Int(-diff / 60)
            if overdueMinutes < 60 {
                return "\(overdueMinutes)分経過 (お急ぎください!)"
            } else {
                let hours = overdueMinutes / 60
                return "\(hours)時間経過 (お急ぎください!)"
            }
        }
        
        let seconds = Int(diff)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        
        if days > 0 {
            return "あと \(days)日"
        } else if hours > 0 {
            let remainingMin = minutes % 60
            if remainingMin > 0 {
                return "あと \(hours)時間\(remainingMin)分"
            }
            return "あと \(hours)時間"
        } else if minutes > 0 {
            return "あと \(minutes)分！"
        } else {
            return "まもなく時間です！"
        }
    }
    
    /// 老若男女にわかりやすい日付・時間表示
    public var formattedDateTime: String {
        if let loc = locationTarget {
            return "📍 \(loc.name)"
        }
        
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        
        if calendar.isDateInToday(targetDate) {
            formatter.dateFormat = "今日 HH:mm"
        } else if calendar.isDateInTomorrow(targetDate) {
            formatter.dateFormat = "明日 HH:mm"
        } else {
            formatter.dateFormat = "M月d日(E) HH:mm"
        }
        return formatter.string(from: targetDate)
    }
}
