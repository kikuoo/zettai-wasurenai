import Foundation
import Combine
import WidgetKit

public final class ReminderStore: ObservableObject {
    public static let shared = ReminderStore()
    
    public static let appGroupIdentifier = "group.com.zettaiwasurenai.app"
    private static let storageKey = "SavedReminderItems_v1"
    private static let presetsStorageKey = "SavedCustomPresets_v1"
    
    @Published public var reminders: [ReminderItem] = [] {
        didSet {
            save()
        }
    }
    
    @Published public var customPresets: [CustomPreset] = [] {
        didSet {
            savePresets()
        }
    }
    
    /// 現在画面上で大暴れ発火中のリマインダー（激震アラームモード）
    @Published public var activeAlarmItem: ReminderItem? = nil
    
    private var checkTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private var userDefaults: UserDefaults {
        UserDefaults(suiteName: ReminderStore.appGroupIdentifier) ?? UserDefaults.standard
    }
    
    public init() {
        load()
        loadPresets()
        if reminders.isEmpty {
            loadInitialSamples()
        }
        if customPresets.isEmpty {
            loadInitialPresets()
        }
        if !reminders.contains(where: { $0.locationTarget != nil }) {
            let sampleLoc = ReminderItem(
                title: "会社に着いたら業務連絡",
                category: .contact,
                targetDate: Date(),
                repeatOption: .none,
                isGekiMode: true,
                isVoiceAlert: true,
                isLightAlert: true,
                locationTarget: LocationTarget(name: "会社・オフィス", latitude: 35.681236, longitude: 139.767125, radius: 100, notifyOnEntry: true, notifyOnExit: false)
            )
            reminders.append(sampleLoc)
        }
        save()
        startMonitoring()
        listenForNotificationOpen()
    }
    
    private func listenForNotificationOpen() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenReminderFromNotification"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let uuid = notification.userInfo?["reminderId"] as? UUID,
               let item = self?.reminders.first(where: { $0.id == uuid && !$0.isCompleted }) {
                self?.triggerAlarm(for: item)
            }
        }
    }
    
    /// 期限監視タイマーを開始
    public func startMonitoring() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkForDueReminders()
        }
    }
    
    /// 期限が到来したリマインダーをチェックしてアラームを起動
    public func checkForDueReminders() {
        guard activeAlarmItem == nil else { return } // 既に発動中なら何もしない
        
        let now = Date()
        // 過去1分以内に到来した、未完了のリマインダー（地図・場所指定のものは除外）
        if let dueItem = reminders.first(where: { item in
            !item.isCompleted &&
            item.locationTarget == nil &&
            item.targetDate <= now &&
            now.timeIntervalSince(item.targetDate) < 60
        }) {
            triggerAlarm(for: dueItem)
        }
    }
    
    /// アラームを発動
    public func triggerAlarm(for item: ReminderItem) {
        activeAlarmItem = item
        
        // 音声読み上げ
        if item.isVoiceAlert {
            SpeechManager.shared.startRepeatingSpeech(taskTitle: item.title)
        }
        
        // 光（フラッシュライト点滅）
        if item.isLightAlert {
            FlashlightManager.shared.startStrobeFlash()
        }
        
        // 激しいアラーム音 & バイブレーション
        if item.isGekiMode {
            SoundEffectManager.shared.startIntenseAlarm()
        }
    }
    
    /// アラームを安全に解除・停止する
    public func dismissActiveAlarm(markCompleted: Bool = false) {
        guard let current = activeAlarmItem else { return }
        
        FlashlightManager.shared.stopStrobeFlash()
        SpeechManager.shared.stop()
        SoundEffectManager.shared.stopAlarm()
        
        if markCompleted {
            toggleCompleted(id: current.id)
            SoundEffectManager.shared.playSuccessSound()
        }
        
        activeAlarmItem = nil
    }
    
    // MARK: - CRUD
    
    public func add(item: ReminderItem) {
        reminders.append(item)
        if item.locationTarget == nil {
            NotificationManager.shared.scheduleNotification(for: item)
        } else {
            NotificationManager.shared.cancelNotification(for: item)
            LocationManager.shared.scheduleLocationNotification(for: item)
        }
        syncToWidget()
    }
    
    public func update(item: ReminderItem) {
        if let index = reminders.firstIndex(where: { $0.id == item.id }) {
            reminders[index] = item
            if item.locationTarget == nil {
                LocationManager.shared.cancelLocationNotification(for: item)
                NotificationManager.shared.scheduleNotification(for: item)
            } else {
                NotificationManager.shared.cancelNotification(for: item)
                LocationManager.shared.scheduleLocationNotification(for: item)
            }
            syncToWidget()
        }
    }
    
    public func delete(id: UUID) {
        if let item = reminders.first(where: { $0.id == id }) {
            NotificationManager.shared.cancelNotification(for: item)
            LocationManager.shared.cancelLocationNotification(for: item)
        }
        VoiceSoundGenerator.shared.removeSound(for: id)
        reminders.removeAll(where: { $0.id == id })
        syncToWidget()
    }
    
    /// 完了済みのやることを一括削除し、削除件数を返す
    @discardableResult
    public func deleteAllCompleted() -> Int {
        let completed = reminders.filter { $0.isCompleted }
        guard !completed.isEmpty else { return 0 }
        for item in completed {
            NotificationManager.shared.cancelNotification(for: item)
            LocationManager.shared.cancelLocationNotification(for: item)
            VoiceSoundGenerator.shared.removeSound(for: item.id)
        }
        reminders.removeAll(where: { $0.isCompleted })
        syncToWidget()
        return completed.count
    }
    
    public var completedCount: Int {
        reminders.filter { $0.isCompleted }.count
    }
    
    public func toggleCompleted(id: UUID) {
        guard let index = reminders.firstIndex(where: { $0.id == id }) else { return }
        var item = reminders[index]
        
        if !item.isCompleted {
            // 完了にする
            item.isCompleted = true
            NotificationManager.shared.cancelNotification(for: item)
            LocationManager.shared.cancelLocationNotification(for: item)
            
            // リピート設定がある場合は次の日時で新しいタスクを作成
            if item.repeatOption != .none, let nextDate = item.repeatOption.nextDate(after: item.targetDate) {
                let nextItem = ReminderItem(
                    title: item.title,
                    category: item.category,
                    targetDate: nextDate,
                    repeatOption: item.repeatOption,
                    isGekiMode: item.isGekiMode,
                    isVoiceAlert: item.isVoiceAlert,
                    isLightAlert: item.isLightAlert,
                    locationTarget: item.locationTarget
                )
                reminders[index] = item
                reminders.append(nextItem)
                NotificationManager.shared.scheduleNotification(for: nextItem)
                LocationManager.shared.scheduleLocationNotification(for: nextItem)
            } else {
                reminders[index] = item
            }
        } else {
            // 未完了に戻す
            item.isCompleted = false
            reminders[index] = item
            NotificationManager.shared.scheduleNotification(for: item)
            LocationManager.shared.scheduleLocationNotification(for: item)
        }
        
        syncToWidget()
    }
    
    // MARK: - カスタムプリセット管理
    
    public func addCustomPreset(title: String, category: ReminderCategory, iconName: String) {
        let preset = CustomPreset(title: title, category: category, iconName: iconName)
        customPresets.append(preset)
    }
    
    public func deleteCustomPreset(id: UUID) {
        customPresets.removeAll(where: { $0.id == id })
    }
    
    // MARK: - ウィジェット同期 & 永続化
    
    public func syncToWidget() {
        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(reminders)
            // 1. App Group UserDefaults
            userDefaults.set(data, forKey: ReminderStore.storageKey)
            userDefaults.synchronize()
            // 2. Standard UserDefaults (フォールバック)
            UserDefaults.standard.set(data, forKey: ReminderStore.storageKey)
            UserDefaults.standard.synchronize()
            
            // 3. 共有ファイルコンテナへの直接保存（アトミック書き込みで破損防止・即時反映）
            if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ReminderStore.appGroupIdentifier) {
                let fileURL = containerURL.appendingPathComponent("reminders.json")
                try? data.write(to: fileURL, options: .atomic)
            }
        } catch {
            print("Failed to save reminders: \(error)")
        }
        syncToWidget()
    }
    
    private func load() {
        // ファイルコンテナ優先
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ReminderStore.appGroupIdentifier) {
            let fileURL = containerURL.appendingPathComponent("reminders.json")
            if let data = try? Data(contentsOf: fileURL),
               let items = try? JSONDecoder().decode([ReminderItem].self, from: data) {
                reminders = items
                return
            }
        }
        
        // UserDefaults
        if let data = userDefaults.data(forKey: ReminderStore.storageKey) ?? UserDefaults.standard.data(forKey: ReminderStore.storageKey),
           let items = try? JSONDecoder().decode([ReminderItem].self, from: data) {
            reminders = items
        }
    }
    
    private func savePresets() {
        do {
            let data = try JSONEncoder().encode(customPresets)
            userDefaults.set(data, forKey: ReminderStore.presetsStorageKey)
            UserDefaults.standard.set(data, forKey: ReminderStore.presetsStorageKey)
        } catch {
            print("Failed to save presets: \(error)")
        }
    }
    
    private func loadPresets() {
        if let data = userDefaults.data(forKey: ReminderStore.presetsStorageKey) ?? UserDefaults.standard.data(forKey: ReminderStore.presetsStorageKey),
           let items = try? JSONDecoder().decode([CustomPreset].self, from: data) {
            customPresets = items
        }
    }
    
    private func loadInitialPresets() {
        customPresets = [
            CustomPreset(title: "お薬を飲む", category: .medicine, iconName: "pill.fill"),
            CustomPreset(title: "ゴミを出す", category: .garbage, iconName: "trash.fill"),
            CustomPreset(title: "戸締まり・火の元", category: .security, iconName: "lock.shield.fill"),
            CustomPreset(title: "お買い物", category: .shopping, iconName: "cart.fill"),
            CustomPreset(title: "電話・連絡", category: .contact, iconName: "phone.fill"),
            CustomPreset(title: "換気をする", category: .general, iconName: "wind"),
            CustomPreset(title: "洗濯物を取り込む", category: .general, iconName: "tshirt.fill")
        ]
    }
    
    private func loadInitialSamples() {
        let calendar = Calendar.current
        let now = Date()
        
        let sample1 = ReminderItem(
            title: "お薬を飲む",
            category: .medicine,
            targetDate: calendar.date(byAdding: .minute, value: 15, to: now) ?? now,
            repeatOption: .daily,
            isGekiMode: true,
            isVoiceAlert: true,
            isLightAlert: true
        )
        
        let sample2 = ReminderItem(
            title: "戸締まり・火の元チェック",
            category: .security,
            targetDate: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
            repeatOption: .none,
            isGekiMode: true,
            isVoiceAlert: true,
            isLightAlert: true
        )
        
        let sample3 = ReminderItem(
            title: "燃えるゴミを出す",
            category: .garbage,
            targetDate: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
            repeatOption: .weekly,
            isGekiMode: false,
            isVoiceAlert: true,
            isLightAlert: false
        )
        
        reminders = [sample1, sample2, sample3]
    }
}
