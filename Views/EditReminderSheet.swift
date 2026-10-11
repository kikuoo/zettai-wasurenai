import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 既存のリマインダー（やること）を編集・更新するシート
public struct EditReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ReminderStore
    @ObservedObject var subManager = SubscriptionManager.shared
    
    let originalItem: ReminderItem
    
    @State private var title: String
    @State private var selectedCategory: ReminderCategory
    @State private var targetDate: Date
    @State private var repeatOption: RepeatOption
    @State private var isGekiMode: Bool
    @State private var isVoiceAlert: Bool
    @State private var isLightAlert: Bool
    @State private var locationTarget: LocationTarget?
    
    @State private var showCustomDatePicker: Bool = false
    @State private var showLocationPicker: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showPaywallSheet: Bool = false
    
    public init(item: ReminderItem, store: ReminderStore) {
        self.originalItem = item
        self.store = store
        _title = State(initialValue: item.title)
        _selectedCategory = State(initialValue: item.category)
        _targetDate = State(initialValue: item.targetDate)
        _repeatOption = State(initialValue: item.repeatOption)
        _isGekiMode = State(initialValue: item.isGekiMode)
        _isVoiceAlert = State(initialValue: item.isVoiceAlert)
        _isLightAlert = State(initialValue: item.isLightAlert)
        _locationTarget = State(initialValue: item.locationTarget)
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - 1. タイトルとカテゴリ
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. やることの内容")
                            .font(.system(size: 18, weight: .bold))
                        
                        // カテゴリ選択
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(ReminderCategory.allCases) { cat in
                                    Button(action: {
                                        #if canImport(UIKit)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        #endif
                                        selectedCategory = cat
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: cat.iconName)
                                            Text(cat.title)
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(selectedCategory == cat ? cat.color : Color(UIColor.secondarySystemGroupedBackground))
                                        )
                                        .foregroundColor(selectedCategory == cat ? .white : .primary)
                                        .overlay(
                                            Capsule().stroke(selectedCategory == cat ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        
                        // 入力ボックス
                        HStack {
                            Image(systemName: selectedCategory.iconName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(selectedCategory.color)
                                .padding(.leading, 8)
                            
                            TextField("やることのタイトル", text: $title)
                                .font(.system(size: 19, weight: .semibold))
                                .padding(.vertical, 14)
                        }
                        .padding(.horizontal, 10)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    
                    // MARK: - 2. 日時設定
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("2. お知らせ日時")
                                .font(.system(size: 18, weight: .bold))
                            Spacer()
                            if locationTarget != nil {
                                Label("場所指定中・日時設定無効", systemImage: "lock.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.teal.opacity(0.15))
                                    .foregroundColor(.teal)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if let loc = locationTarget {
                            // 地図で場所を設定した場合は日時の設定を無効化
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.teal)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("地図での場所指定が設定されています")
                                            .font(.system(size: 15, weight: .bold))
                                            .foregroundColor(.primary)
                                        Text("「\(loc.name)」へ\(loc.notifyOnEntry ? "到着" : "")\(loc.notifyOnEntry && loc.notifyOnExit ? "・" : "")\(loc.notifyOnExit ? "出発" : "")した時にお知らせします")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Divider()
                                
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 12))
                                        Text("場所連動のため日時の指定は無効です")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        withAnimation {
                                            locationTarget = nil
                                        }
                                    }) {
                                        Text("場所を解除して日時に変更")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.blue.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.teal.opacity(0.4), lineWidth: 1.5)
                            )
                        } else {
                            // クイック時間プリセットボタン
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                TimePresetButton(title: "10分後", subtitle: formatOffset(min: 10), iconName: "bolt.badge.clock.fill", isSelected: false) {
                                    targetDate = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
                                }
                                TimePresetButton(title: "30分後", subtitle: formatOffset(min: 30), iconName: "clock.arrow.circlepath", isSelected: false) {
                                    targetDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
                                }
                                TimePresetButton(title: "1時間後", subtitle: formatOffset(min: 60), iconName: "hourglass.bottomhalf.filled", isSelected: false) {
                                    targetDate = Calendar.current.date(byAdding: .minute, value: 60, to: Date()) ?? Date()
                                }
                                TimePresetButton(title: "今夜", subtitle: "20:00", iconName: "moon.stars.fill", isSelected: false) {
                                    setTonight()
                                }
                                TimePresetButton(title: "明日の朝", subtitle: "08:00", iconName: "sun.and.horizon.fill", isSelected: false) {
                                    setTomorrow(hour: 8)
                                }
                                TimePresetButton(title: "明日の昼", subtitle: "12:00", iconName: "sun.max.fill", isSelected: false) {
                                    setTomorrow(hour: 12)
                                }
                            }
                            
                            // 日時表示
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("予定日時")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text(formattedDate(targetDate))
                                        .font(.system(size: 20, weight: .heavy))
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                                Button(action: { withAnimation { showCustomDatePicker.toggle() } }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: showCustomDatePicker ? "chevron.up" : "calendar")
                                        Text(showCustomDatePicker ? "閉じる" : "日時を微調整")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(14)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            
                            if showCustomDatePicker {
                                DatePicker("日時", selection: $targetDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    
                    // MARK: - 3. 場所による通知（地図指定）
                    VStack(alignment: .leading, spacing: 12) {
                        Text("3. 場所でお知らせ (地図指定)")
                            .font(.system(size: 18, weight: .bold))
                        
                        Button(action: {
                            if subManager.isPro {
                                showLocationPicker = true
                            } else {
                                showPaywallSheet = true
                            }
                        }) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(locationTarget != nil ? Color.green.opacity(0.15) : (!subManager.isPro ? Color.orange.opacity(0.12) : Color.blue.opacity(0.12)))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: locationTarget != nil ? "mappin.and.ellipse" : (!subManager.isPro ? "lock.fill" : "map.fill"))
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(locationTarget != nil ? .green : (!subManager.isPro ? .orange : .blue))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(locationTarget != nil ? locationTarget!.summaryText : "場所を指定していません")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.primary)
                                        if !subManager.isPro {
                                            Text("プレミアム")
                                                .font(.system(size: 10, weight: .heavy))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.15))
                                                .foregroundColor(.orange)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(locationTarget != nil ? "タップして場所や範囲を変更" : (!subManager.isPro ? "自宅・会社・駅の到着時に通知（月額300円）" : "自宅や会社、駅に着いた時に通知"))
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - 4. お知らせ方法
                    VStack(alignment: .leading, spacing: 14) {
                        Text("4. お知らせ方法")
                            .font(.system(size: 18, weight: .bold))
                        
                        VStack(spacing: 14) {
                            Toggle(isOn: $isGekiMode) {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.red)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("激しくお知らせモード")
                                            .font(.system(size: 16, weight: .heavy))
                                        Text("気づくまでスヌーズ連打＆大音量")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(.red)
                            
                            Divider()
                            
                            Toggle(isOn: $isLightAlert) {
                                HStack(spacing: 12) {
                                    Image(systemName: "flashlight.on.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("音と光（カメラフラッシュ点滅）")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("背面のライトがピカピカ点滅")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(.orange)
                            
                            Divider()
                            
                            Toggle(isOn: $isVoiceAlert) {
                                HStack(spacing: 12) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.purple)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("音声で読み上げる")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("声で「○○の時間です」とお知らせ")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(.purple)
                        }
                        .padding(16)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    
                    // MARK: - 5. 繰り返し設定
                    VStack(alignment: .leading, spacing: 12) {
                        Text("5. 繰り返し")
                            .font(.system(size: 18, weight: .bold))
                        
                        if locationTarget != nil {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(.teal)
                                Text("場所連動（指定場所に到着・出発するたびにお知らせ）")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            Picker("繰り返し", selection: $repeatOption) {
                                ForEach(RepeatOption.allCases) { opt in
                                    Text(opt.title).tag(opt)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    
                    // MARK: - 保存ボタン
                    Button(action: saveChanges) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("変更を保存する")
                                .font(.system(size: 18, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .padding(.top, 10)
                    
                    // MARK: - 削除ボタン
                    Button(action: { showDeleteConfirm = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("このやること・予定を削除する")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                    }
                    .confirmationDialog("このやること・予定を削除しますか？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                        Button("削除する", role: .destructive) {
                            store.delete(id: originalItem.id)
                            dismiss()
                        }
                        Button("キャンセル", role: .cancel) {}
                    }
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("やることの編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveChanges() }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(locationTarget: $locationTarget)
            }
            .sheet(isPresented: $showPaywallSheet) {
                PaywallView()
            }
        }
    }
    
    private func saveChanges() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedCategory.title : title
        var updated = originalItem
        updated.title = finalTitle
        updated.category = selectedCategory
        updated.targetDate = targetDate
        updated.repeatOption = locationTarget != nil ? .none : repeatOption
        updated.isGekiMode = isGekiMode
        updated.isVoiceAlert = isVoiceAlert
        updated.isLightAlert = isLightAlert
        updated.locationTarget = locationTarget
        
        store.update(item: updated)
        dismiss()
    }
    
    private func formatOffset(min: Int) -> String {
        guard let d = Calendar.current.date(byAdding: .minute, value: min, to: Date()) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: d)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "今日 HH:mm"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "明日 HH:mm"
        } else {
            formatter.dateFormat = "M月d日(E) HH:mm"
        }
        return formatter.string(from: date)
    }
    
    private func setTonight() {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 20
        comps.minute = 0
        if let d = Calendar.current.date(from: comps) {
            targetDate = d > Date() ? d : Calendar.current.date(byAdding: .day, value: 1, to: d) ?? d
        }
    }
    
    private func setTomorrow(hour: Int) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = hour
        comps.minute = 0
        targetDate = Calendar.current.date(from: comps) ?? tomorrow
    }
}
