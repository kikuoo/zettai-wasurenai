import Foundation

public enum RepeatOption: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case daily = "daily"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case weekly = "weekly"
    case hourly = "hourly"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .none: return "1回のみ (繰返しなし)"
        case .daily: return "毎日"
        case .weekdays: return "平日 (月〜金)"
        case .weekends: return "週末 (土・日)"
        case .weekly: return "毎週同じ曜日"
        case .hourly: return "1時間ごと"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .none: return "なし"
        case .daily: return "毎日"
        case .weekdays: return "平日"
        case .weekends: return "土日"
        case .weekly: return "毎週"
        case .hourly: return "毎時"
        }
    }
    
    public func nextDate(after date: Date) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let baseDate = max(date, now)
        
        switch self {
        case .none:
            return nil
            
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: baseDate)
            
        case .weekdays:
            var next = calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
            while calendar.isDateInWeekend(next) {
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
            }
            return next
            
        case .weekends:
            var next = calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
            while !calendar.isDateInWeekend(next) {
                next = calendar.date(byAdding: .day, value: 1, to: next) ?? next
            }
            return next
            
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: baseDate)
            
        case .hourly:
            return calendar.date(byAdding: .hour, value: 1, to: baseDate)
        }
    }
}
