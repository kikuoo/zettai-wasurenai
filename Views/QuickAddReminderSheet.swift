import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// 老若男女が手軽に、迷わず入力できるやること登録シート
public struct QuickAddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: ReminderStore
    @ObservedObject var subManager = SubscriptionManager.shared
    
    // 入力状態
    @State private var title: String = ""
    @State private var selectedCategory: ReminderCategory = .medicine
    @State private var targetDate: Date = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
    @State private var repeatOption: RepeatOption = .none
    
    // アラート設定
    @State private var isGekiMode: Bool = true
    @State private var isVoiceAlert: Bool = true
    @State private var isLightAlert: Bool = true
    
    // 場所設定
    @State private var locationTarget: LocationTarget? = nil
    
    // シート表示フラグ
    @State private var showCustomDatePicker: Bool = false
    @State private var showLocationPicker: Bool = false
    @State private var showAddPresetSheet: Bool = false
    @State private var showPaywallSheet: Bool = false
    
    // クイックプリセット選択状態
    @State private var selectedPresetTag: String? = "30min"
    
    public init(store: ReminderStore) {
        self.store = store
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - 1. やること（ワンタップ選択 & 直接入力）
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("1. やることを選ぶ・入力する")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                            // ワンタップ追加ボタン
                            Button(action: {
                                if subManager.isPro {
                                    showAddPresetSheet = true
                                } else {
                                    showPaywallSheet = true
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: !subManager.isPro ? "crown.fill" : "plus.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(!subManager.isPro ? .orange : .blue)
                                    Text("定番を追加")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(!subManager.isPro ? .orange : .blue)
                            }
                        }
                        
                        // ワンタップ定型ボタン（カスタム追加項目対応）
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(store.customPresets) { preset in
                                    Button(action: {
                                        #if canImport(UIKit)
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        #endif
                                        selectedCategory = preset.category
                                        title = preset.title
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: preset.iconName)
                                            Text(preset.title)
                                                .font(.system(size: 14, weight: .bold))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(
                                            Capsule()
                                                .fill(title == preset.title ? preset.category.color : Color(UIColor.secondarySystemGroupedBackground))
                                        )
                                        .foregroundColor(title == preset.title ? .white : .primary)
                                        .overlay(
                                            Capsule().stroke(title == preset.title ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                    .contextMenu {
                                        Button(role: .destructive, action: {
                                            store.deleteCustomPreset(id: preset.id)
                                        }) {
                                            Label("この定番項目を削除", systemImage: "trash")
                                        }
                                    }
                                }
                                
                                // 追加ボタン
                                Button(action: {
                                    if subManager.isPro {
                                        showAddPresetSheet = true
                                    } else {
                                        showPaywallSheet = true
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: !subManager.isPro ? "crown.fill" : "plus")
                                            .foregroundColor(!subManager.isPro ? .orange : .blue)
                                        Text("新しい項目")
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(!subManager.isPro ? Color.orange.opacity(0.12) : Color.blue.opacity(0.12))
                                    .foregroundColor(!subManager.isPro ? .orange : .blue)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        
                        // タイトル入力ボックス（大きく見やすい）
                        HStack {
                            Image(systemName: selectedCategory.iconName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(selectedCategory.color)
                                .padding(.leading, 8)
                            
                            TextField("例: 朝の血圧の薬を飲む", text: $title)
                                .font(.system(size: 19, weight: .semibold))
                                .padding(.vertical, 14)
                            
                            if !title.isEmpty {
                                Button(action: { title = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.trailing, 8)
                            }
                        }
                        .padding(.horizontal, 10)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1.5)
                        )
                    }
                    
                    // MARK: - 2. 時間設定（ワンタップ簡単ボタン群）
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("2. いつ知らせる？")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
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
                                            selectedPresetTag = "30min"
                                            targetDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
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
                            // クイック時間プリセットボタン（3列グリッド）
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                TimePresetButton(
                                    title: "10分後",
                                    subtitle: formatTime(minutesFromNow: 10),
                                    iconName: "bolt.badge.clock.fill",
                                    isSelected: selectedPresetTag == "10min"
                                ) {
                                    selectPreset(tag: "10min", minutes: 10)
                                }
                                
                                TimePresetButton(
                                    title: "30分後",
                                    subtitle: formatTime(minutesFromNow: 30),
                                    iconName: "clock.arrow.circlepath",
                                    isSelected: selectedPresetTag == "30min"
                                ) {
                                    selectPreset(tag: "30min", minutes: 30)
                                }
                                
                                TimePresetButton(
                                    title: "1時間後",
                                    subtitle: formatTime(minutesFromNow: 60),
                                    iconName: "hourglass.bottomhalf.filled",
                                    isSelected: selectedPresetTag == "60min"
                                ) {
                                    selectPreset(tag: "60min", minutes: 60)
                                }
                                
                                TimePresetButton(
                                    title: "今夜",
                                    subtitle: "20:00",
                                    iconName: "moon.stars.fill",
                                    isSelected: selectedPresetTag == "tonight"
                                ) {
                                    selectTonightPreset()
                                }
                                
                                TimePresetButton(
                                    title: "明日の朝",
                                    subtitle: "08:00",
                                    iconName: "sun.and.horizon.fill",
                                    isSelected: selectedPresetTag == "tomorrow_morning"
                                ) {
                                    selectTomorrowPreset(hour: 8)
                                }
                                
                                TimePresetButton(
                                    title: "明日の昼",
                                    subtitle: "12:00",
                                    iconName: "sun.max.fill",
                                    isSelected: selectedPresetTag == "tomorrow_noon"
                                ) {
                                    selectTomorrowPreset(hour: 12)
                                }
                            }
                            
                            // 現在選択されている日時プレビューカード
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("お知らせ予定日時")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text(formattedTargetDate(targetDate))
                                        .font(.system(size: 20, weight: .heavy))
                                        .foregroundColor(.blue)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation {
                                        showCustomDatePicker.toggle()
                                    }
                                }) {
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
                            
                            // 詳細日時ピッカー（展開時）
                            if showCustomDatePicker {
                                DatePicker(
                                    "通知日時",
                                    selection: $targetDate,
                                    in: Date()...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .onChange(of: targetDate) { _ in
                                    selectedPresetTag = nil
                                }
                            }
                        }
                    }
                    
                    // MARK: - 3. 場所でお知らせ（地図指定）
                    VStack(alignment: .leading, spacing: 12) {
                        Text("3. 場所でお知らせ (地図指定)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
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
                                        Text(locationTarget != nil ? locationTarget!.summaryText : "場所を指定する（タップ）")
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
                                
                                Image(systemName: !subManager.isPro ? "chevron.right" : "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(14)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // MARK: - 4. 激しくお知らせモード（鬼アラーム）
                    VStack(alignment: .leading, spacing: 14) {
                        Text("4. お知らせ方法")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 14) {
                            // 激しくお知らせモードトグル
                            Toggle(isOn: $isGekiMode) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.red.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "bell.badge.fill")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.red)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("激しくお知らせモード")
                                            .font(.system(size: 17, weight: .heavy))
                                            .foregroundColor(.primary)
                                        Text("絶対に気づくまで鳴動・スヌーズ連打")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(.red)
                            
                            Divider()
                            
                            // 音と光（カメラフラッシュ）
                            Toggle(isOn: $isLightAlert) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.orange.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "flashlight.on.fill")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.orange)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("音と光（カメラフラッシュ点滅）")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("スマホの背面ライトがピカピカ点滅")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(.orange)
                            
                            Divider()
                            
                            // 音声で知らせる
                            Toggle(isOn: $isVoiceAlert) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.purple.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "waveform")
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.purple)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("音声で読み上げる")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("「○○の時間です！」と声でお知らせ")
                                            .font(.system(size: 12, weight: .medium))
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
                            .foregroundColor(.primary)
                        
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
                    
                    // MARK: - 決定・登録ボタン（特大・老若男女が絶対に押せる）
                    Button(action: saveReminder) {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.badge.fill")
                                .font(.system(size: 22, weight: .bold))
                            Text("この内容で絶対に忘れない設定にする")
                                .font(.system(size: 18, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color(red: 0.1, green: 0.4, blue: 0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("やることの登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(locationTarget: $locationTarget)
            }
            .sheet(isPresented: $showAddPresetSheet) {
                AddCustomPresetSheet(store: store)
            }
            .sheet(isPresented: $showPaywallSheet) {
                PaywallView()
            }
            .onAppear {
                if title.isEmpty {
                    title = selectedCategory.title
                }
            }
        }
    }
    
    // MARK: - ヘルパー関数
    
    private func selectPreset(tag: String, minutes: Int) {
        selectedPresetTag = tag
        targetDate = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) ?? Date()
    }
    
    private func selectTonightPreset() {
        selectedPresetTag = "tonight"
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 20
        comps.minute = 0
        if let tonightDate = calendar.date(from: comps) {
            targetDate = tonightDate > Date() ? tonightDate : Calendar.current.date(byAdding: .day, value: 1, to: tonightDate) ?? tonightDate
        }
    }
    
    private func selectTomorrowPreset(hour: Int) {
        selectedPresetTag = (hour == 8) ? "tomorrow_morning" : "tomorrow_noon"
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        var comps = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        comps.hour = hour
        comps.minute = 0
        targetDate = calendar.date(from: comps) ?? tomorrow
    }
    
    private func formatTime(minutesFromNow: Int) -> String {
        guard let d = Calendar.current.date(byAdding: .minute, value: minutesFromNow, to: Date()) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: d)
    }
    
    private func formattedTargetDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "今日 HH:mm"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "明日 HH:mm"
        } else {
            formatter.dateFormat = "M月d日(E) HH:mm"
        }
        return formatter.string(from: date)
    }
    
    private func saveReminder() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        let finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedCategory.title : title
        
        let newReminder = ReminderItem(
            title: finalTitle,
            category: selectedCategory,
            targetDate: targetDate,
            repeatOption: locationTarget != nil ? .none : repeatOption,
            isGekiMode: isGekiMode,
            isVoiceAlert: isVoiceAlert,
            isLightAlert: isLightAlert,
            locationTarget: locationTarget
        )
        
        store.add(item: newReminder)
        dismiss()
    }
}
