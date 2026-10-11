import WidgetKit
import SwiftUI

struct ReminderEntry: TimelineEntry {
    let date: Date
    let nextItem: ReminderItem?
    let upcomingItems: [ReminderItem]
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> ReminderEntry {
        let sample = ReminderItem(
            title: "お薬を飲む",
            category: .medicine,
            targetDate: Calendar.current.date(byAdding: .minute, value: 20, to: Date()) ?? Date(),
            isGekiMode: true
        )
        return ReminderEntry(date: Date(), nextItem: sample, upcomingItems: [sample])
    }

    func getSnapshot(in context: Context, completion: @escaping (ReminderEntry) -> ()) {
        let entry = loadCurrentEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReminderEntry>) -> ()) {
        let entry = loadCurrentEntry()
        let now = Date()
        // 直近のリマインダー時刻、または最短1分〜最長3分後にタイムライン更新
        var nextUpdate = Calendar.current.date(byAdding: .minute, value: 3, to: now) ?? now
        if let target = entry.nextItem?.targetDate, target > now {
            nextUpdate = min(nextUpdate, target)
        }
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadCurrentEntry() -> ReminderEntry {
        var reminders: [ReminderItem] = []
        
        // 1. App Group 共有コンテナファイル優先
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.zettaiwasurenai.app") {
            let fileURL = containerURL.appendingPathComponent("reminders.json")
            if let data = try? Data(contentsOf: fileURL),
               let items = try? JSONDecoder().decode([ReminderItem].self, from: data) {
                reminders = items
            }
        }
        
        // 2. App Group UserDefaults
        if reminders.isEmpty {
            if let defaults = UserDefaults(suiteName: "group.com.zettaiwasurenai.app"),
               let data = defaults.data(forKey: "SavedReminderItems_v1"),
               let items = try? JSONDecoder().decode([ReminderItem].self, from: data) {
                reminders = items
            }
        }
        
        // 3. Standard UserDefaults (フォールバック)
        if reminders.isEmpty {
            if let data = UserDefaults.standard.data(forKey: "SavedReminderItems_v1"),
               let items = try? JSONDecoder().decode([ReminderItem].self, from: data) {
                reminders = items
            }
        }
        
        let pending = reminders.filter { !$0.isCompleted }.sorted { item1, item2 in
            // 場所通知があるものは通常スケジュールと並列で直近として扱う
            return item1.targetDate < item2.targetDate
        }
        
        return ReminderEntry(
            date: Date(),
            nextItem: pending.first,
            upcomingItems: Array(pending.dropFirst().prefix(2))
        )
    }
}

struct ZettaiWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Small ウィジェット
struct SmallWidgetView: View {
    let entry: ReminderEntry
    
    var body: some View {
        if let item = entry.nextItem {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: item.category.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(item.category.color)
                    
                    Spacer()
                    
                    if item.isGekiMode {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                    }
                }
                
                Spacer()
                
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(item.formattedRemainingTime)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(item.isOverdue ? .red : .blue)
                
                Text(item.formattedDateTime)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .widgetURL(URL(string: "zettaiwasurenai://item?id=\(item.id.uuidString)"))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
                Text("予定なし")
                    .font(.system(size: 15, weight: .bold))
                Text("忘れる心配なし！")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
    }
}

// MARK: - Medium ウィジェット
struct MediumWidgetView: View {
    let entry: ReminderEntry
    
    var body: some View {
        if let item = entry.nextItem {
            HStack(spacing: 12) {
                // 左側：最優先タスクカード
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: item.category.iconName)
                            .foregroundColor(item.category.color)
                        Text("次の予定")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        if item.isGekiMode {
                            Text("激震")
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.red.opacity(0.15))
                                .foregroundColor(.red)
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(item.title)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(2)
                    
                    Spacer()
                    
                    HStack {
                        Text(item.formattedRemainingTime)
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(item.isOverdue ? .red : .blue)
                        Spacer()
                        Text(item.formattedDateTime)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(Color.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                // 右側：その後の予定
                if !entry.upcomingItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("その後の予定")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        ForEach(entry.upcomingItems) { next in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(next.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                Text(next.formattedDateTime)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: 120)
                }
            }
            .padding(12)
            .widgetURL(URL(string: "zettaiwasurenai://item?id=\(item.id.uuidString)"))
        } else {
            HStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("すべての予定が完了しています")
                        .font(.system(size: 16, weight: .bold))
                    Text("アプリを開いて新しいやること・予定を登録できます")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
        }
    }
}

public struct ZettaiWidget: Widget {
    let kind: String = "ZettaiWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ZettaiWidgetEntryView(entry: entry)
                .containerBackground(Color(UIColor.systemBackground), for: .widget)
        }
        .configurationDisplayName("絶対忘れない！ウィジェット")
        .description("直近のやること・残り時間をホーム画面に大きく表示します。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
