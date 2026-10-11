import SwiftUI

public enum ReminderCategory: String, Codable, CaseIterable, Identifiable {
    case medicine = "medicine"
    case garbage = "garbage"
    case security = "security"
    case shopping = "shopping"
    case contact = "contact"
    case general = "general"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .medicine: return "お薬を飲む"
        case .garbage: return "ゴミを出す"
        case .security: return "戸締まり・火の元"
        case .shopping: return "お買い物"
        case .contact: return "電話・連絡"
        case .general: return "その他のやること"
        }
    }
    
    public var iconName: String {
        switch self {
        case .medicine: return "pill.fill"
        case .garbage: return "trash.fill"
        case .security: return "lock.shield.fill"
        case .shopping: return "cart.fill"
        case .contact: return "phone.badge.checkmark"
        case .general: return "checklist"
        }
    }
    
    public var color: Color {
        switch self {
        case .medicine: return Color.pink
        case .garbage: return Color.green
        case .security: return Color.orange
        case .shopping: return Color.blue
        case .contact: return Color.indigo
        case .general: return Color.purple
        }
    }
}
