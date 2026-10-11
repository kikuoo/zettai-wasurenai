import SwiftUI

/// ユーザーが自由に追加・カスタマイズできるワンタップ入力項目
public struct CustomPreset: Identifiable, Codable, Equatable {
    public var id: UUID
    public var title: String
    public var category: ReminderCategory
    public var iconName: String
    
    public init(
        id: UUID = UUID(),
        title: String,
        category: ReminderCategory = .general,
        iconName: String = "checklist"
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.iconName = iconName
    }
}
