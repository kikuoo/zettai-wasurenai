import SwiftUI

/// ユーザーが自分専用の「ワンタップ定型ボタン」を作成・追加するシート
public struct AddCustomPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ReminderStore
    
    @State private var title: String = ""
    @State private var selectedCategory: ReminderCategory = .general
    @State private var selectedIcon: String = "star.fill"
    
    private let availableIcons = [
        "star.fill", "pawprint.fill", "cup.and.saucer.fill", "leaf.fill",
        "book.fill", "dumbbell.fill", "car.fill", "cross.case.fill",
        "bag.fill", "bicycle", "lightbulb.fill", "heart.fill"
    ]
    
    public init(store: ReminderStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("新しいワンタップ項目の名前")) {
                    TextField("例: 犬の散歩、換気、体操", text: $title)
                        .font(.system(size: 17, weight: .medium))
                }
                
                Section(header: Text("カテゴリ")) {
                    Picker("カテゴリ", selection: $selectedCategory) {
                        ForEach(ReminderCategory.allCases) { cat in
                            HStack {
                                Image(systemName: cat.iconName)
                                Text(cat.title)
                            }
                            .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("アイコンを選ぶ")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? selectedCategory.color : Color(UIColor.tertiarySystemFill))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("ワンタップ項目の追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加する") {
                        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !finalTitle.isEmpty {
                            store.addCustomPreset(
                                title: finalTitle,
                                category: selectedCategory,
                                iconName: selectedIcon
                            )
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
