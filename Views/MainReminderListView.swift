import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct MainReminderListView: View {
    @StateObject private var store = ReminderStore.shared
    @StateObject private var notifManager = NotificationManager.shared
    @ObservedObject private var subManager = SubscriptionManager.shared
    
    @State private var showAddSheet: Bool = ProcessInfo.processInfo.arguments.contains("-previewAddSheet")
    @State private var showSettingsSheet: Bool = ProcessInfo.processInfo.arguments.contains("-previewSettings")
    @State private var showCompletedSection: Bool = false
    @State private var editingItem: ReminderItem? = ProcessInfo.processInfo.arguments.contains("-previewEdit") ? (ReminderStore.shared.reminders.first(where: { $0.locationTarget != nil }) ?? ReminderStore.shared.reminders.first) : nil
    @State private var itemToDelete: ReminderItem? = nil
    @State private var showPaywallSheet: Bool = ProcessInfo.processInfo.arguments.contains("-previewPaywall")
    
    public init() {
        if ProcessInfo.processInfo.arguments.contains("-previewAlarm") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if let item = ReminderStore.shared.reminders.first {
                    ReminderStore.shared.triggerAlarm(for: item)
                }
            }
        }
    }
    
    // 未完了タスク（日付昇順）
    private var pendingReminders: [ReminderItem] {
        store.reminders.filter { !$0.isCompleted }.sorted { $0.targetDate < $1.targetDate }
    }
    
    // 完了済みタスク（新着順）
    private var completedReminders: [ReminderItem] {
        store.reminders.filter { $0.isCompleted }.sorted { $0.targetDate > $1.targetDate }
    }
    
    // 最も直近の未完了タスク
    private var nextUpcomingReminder: ReminderItem? {
        pendingReminders.first
    }
    
    public var body: some View {
        ZStack {
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // MARK: - 通知オフ警告バナー（未許可時のみ）
                        if !notifManager.isAuthorized {
                            Button(action: {
                                notifManager.requestAuthorization()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.slash.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("通知が許可されていません")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("タップして通知を許可し、絶対忘れないようにしましょう")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white)
                                }
                                .padding(14)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.orange.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // MARK: - 無料プラン制限 / プレミアム会員ステータスバナー
                        if !subManager.isPro {
                            Button(action: { showPaywallSheet = true }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("無料プラン")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.primary)
                                            Text("（未完了 \(pendingReminders.count)/\(SubscriptionManager.freeReminderLimit)件）")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(pendingReminders.count >= SubscriptionManager.freeReminderLimit ? .red : .secondary)
                                        }
                                        Text(pendingReminders.count >= SubscriptionManager.freeReminderLimit ? "上限に達しました。プレミアムで無制限に！" : "月額300円でやること無制限・場所指定・定番追加")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text("解除する")
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .clipShape(Capsule())
                                }
                                .padding(12)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(pendingReminders.count >= SubscriptionManager.freeReminderLimit ? Color.orange.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                        
                        // MARK: - 次に迫っているタスク（スポットライトカード）
                        if let next = nextUpcomingReminder {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("次に迫っている予定", systemImage: "timer")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.blue)
                                    Spacer()
                                    Text(next.formattedRemainingTime)
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundColor(next.isOverdue ? .red : .blue)
                                }
                                
                                ReminderCardView(
                                    item: next,
                                    onToggleComplete: {
                                        store.toggleCompleted(id: next.id)
                                    },
                                    onTestAlarm: {
                                        store.triggerAlarm(for: next)
                                    },
                                    onEdit: {
                                        editingItem = next
                                    },
                                    onDelete: {
                                        itemToDelete = next
                                    }
                                )
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.blue.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.blue.opacity(0.25), lineWidth: 1.5)
                            )
                            .padding(.horizontal, 16)
                        }
                        
                        // MARK: - 未完了のやること一覧
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("未完了のやること")
                                    .font(.system(size: 18, weight: .bold))
                                
                                Spacer()
                                
                                Text("\(pendingReminders.count)件")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 16)
                            
                            if pendingReminders.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(.green.opacity(0.8))
                                    Text("すべてのやることを完了しました！")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text("下の大きなボタンから新しいやること・予定を追加してください")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 36)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .padding(.horizontal, 16)
                            } else {
                                ForEach(pendingReminders) { item in
                                    ReminderCardView(
                                        item: item,
                                        onToggleComplete: {
                                            store.toggleCompleted(id: item.id)
                                        },
                                        onTestAlarm: {
                                            store.triggerAlarm(for: item)
                                        },
                                        onEdit: {
                                            editingItem = item
                                        },
                                        onDelete: {
                                            itemToDelete = item
                                        }
                                    )
                                    .padding(.horizontal, 16)
                                    .contextMenu {
                                        Button(action: { editingItem = item }) {
                                            Label("編集する", systemImage: "pencil")
                                        }
                                        Button(action: { store.triggerAlarm(for: item) }) {
                                            Label("激震アラームを鳴らす", systemImage: "bell.badge.fill")
                                        }
                                        Button(action: { store.toggleCompleted(id: item.id) }) {
                                            Label("完了にする", systemImage: "checkmark.circle")
                                        }
                                        Button(role: .destructive, action: { itemToDelete = item }) {
                                            Label("削除する", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        
                        // MARK: - 完了済みセクション（折りたたみ可能）
                        if !completedReminders.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Button(action: {
                                    withAnimation {
                                        showCompletedSection.toggle()
                                    }
                                }) {
                                    HStack {
                                        Text("完了したやること (\(completedReminders.count))")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Image(systemName: showCompletedSection ? "chevron.up" : "chevron.down")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                                
                                if showCompletedSection {
                                    ForEach(completedReminders) { item in
                                        ReminderCardView(
                                            item: item,
                                            onToggleComplete: {
                                                store.toggleCompleted(id: item.id)
                                            },
                                            onTestAlarm: {},
                                            onEdit: {
                                                editingItem = item
                                            },
                                            onDelete: {
                                                itemToDelete = item
                                            }
                                        )
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                        }
                        
                        // 下部余白（ボタンに被らないよう）
                        Spacer().frame(height: 90)
                    }
                    .padding(.top, 10)
                }
                .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle("絶対忘れない！")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showSettingsSheet = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                }
            }
            
            // MARK: - 画面最下部の大きな「＋ やること追加」ボタン
            VStack {
                Spacer()
                Button(action: {
                    #if canImport(UIKit)
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    #endif
                    if !subManager.isPro && pendingReminders.count >= SubscriptionManager.freeReminderLimit {
                        showPaywallSheet = true
                    } else {
                        showAddSheet = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: (!subManager.isPro && pendingReminders.count >= SubscriptionManager.freeReminderLimit) ? "crown.fill" : "plus.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor((!subManager.isPro && pendingReminders.count >= SubscriptionManager.freeReminderLimit) ? .yellow : .white)
                        Text((!subManager.isPro && pendingReminders.count >= SubscriptionManager.freeReminderLimit) ? "プレミアムで無制限に追加" : "新しいやること・予定を追加")
                            .font(.system(size: 18, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: (!subManager.isPro && pendingReminders.count >= SubscriptionManager.freeReminderLimit) ?
                                [Color.orange, Color(red: 0.9, green: 0.35, blue: 0.1)] :
                                [Color.blue, Color(red: 0.1, green: 0.35, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: (!subManager.isPro && pendingReminders.count >= SubscriptionManager.freeReminderLimit) ? Color.orange.opacity(0.4) : Color.blue.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            
            // MARK: - フルスクリーン超激震アラーム（発火中のみ表示）
            if let activeItem = store.activeAlarmItem {
                IntenseAlarmOverlayView(item: activeItem) { markCompleted in
                    store.dismissActiveAlarm(markCompleted: markCompleted)
                }
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            QuickAddReminderSheet(store: store)
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(store: store)
        }
        .sheet(isPresented: $showPaywallSheet) {
            PaywallView()
        }
        .sheet(item: $editingItem) { item in
            EditReminderSheet(item: item, store: store)
        }
        .confirmationDialog(
            "やることの削除",
            isPresented: Binding(
                get: { itemToDelete != nil },
                set: { if !$0 { itemToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: itemToDelete
        ) { item in
            Button("「\(item.title)」を削除する", role: .destructive) {
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                #endif
                store.delete(id: item.id)
                itemToDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                itemToDelete = nil
            }
        } message: { item in
            Text("このやること・予定をリストから完全に削除しますか？")
        }
    }
}
