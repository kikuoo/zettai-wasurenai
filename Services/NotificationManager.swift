import Foundation
import UserNotifications

/// ローカル通知および「しつこい通知」を管理するクラス
public final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationManager()
    
    @Published public var isAuthorized: Bool = false
    
    public override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupCategories()
        checkAuthorization()
    }
    
    /// インタラクティブ通知カテゴリとアクションの登録
    private func setupCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_ALARM",
            title: "🚨 アラームを開く",
            options: [.foreground]
        )
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_ACTION",
            title: "✅ 完了にする",
            options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE_1MIN",
            title: "⏱ 1分後スヌーズ",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "REMINDER_CATEGORY",
            actions: [openAction, completeAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    /// 権限状態の確認
    public func checkAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional)
            }
        }
    }
    
    /// 通知の許可リクエスト（＋システムアラームの許可）
    public func requestAuthorization(completion: @escaping (Bool) -> Void = { _ in }) {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                completion(granted)
                SystemAlarmManager.shared.requestAuthorization()
            }
        }
    }
    
    /// 激震モードの再通知タイミング（秒）。通知1回ごとにバイブ＋音が鳴るため、短い間隔で連打する
    private static let gekiOffsetsInSeconds: [Int] = [0, 30, 60, 90, 120, 180, 240, 300, 420, 600]
    /// 旧バージョン（分単位）の識別子も含めてキャンセルできるようにする
    private static let legacyOffsetsInMinutes: [Int] = [0, 1, 2, 3, 5]
    
    /// リマインダーの通知をスケジュールする
    public func scheduleNotification(for item: ReminderItem) {
        cancelNotification(for: item)
        
        guard !item.isCompleted else { return }
        
        // 地図・場所指定が設定されている場合は、時間ベースの通知は行わない（場所ジオフェンス通知のみ実行）
        guard item.locationTarget == nil else { return }
        guard item.targetDate > Date() else { return }
        
        // 激震モード → 時計アプリ同等のシステムアラーム（iOS 26.1以降）も併用
        SystemAlarmManager.shared.schedule(for: item)
        
        // 音声お知らせONの場合は「○○の時間です」の読み上げ入りサウンドを生成してから登録
        if item.isVoiceAlert {
            VoiceSoundGenerator.shared.generate(for: item) { [weak self] soundName in
                // 生成中に完了・削除・日時変更された場合は登録しない
                guard let current = ReminderStore.shared.reminders.first(where: { $0.id == item.id }),
                      !current.isCompleted,
                      current.targetDate == item.targetDate,
                      current.locationTarget == nil else { return }
                self?.addRequests(for: item, soundName: soundName ?? "alarm_siren.caf")
            }
        } else {
            addRequests(for: item, soundName: "alarm_siren.caf")
        }
    }
    
    private func addRequests(for item: ReminderItem, soundName: String) {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        let offsets: [Int] = item.isGekiMode ? Self.gekiOffsetsInSeconds : [0]
        
        for offset in offsets {
            let triggerDate = item.targetDate.addingTimeInterval(TimeInterval(offset))
            guard triggerDate > now else { continue }
            
            let content = UNMutableNotificationContent()
            if offset == 0 {
                content.title = item.isGekiMode ? "🚨【絶対に忘れないで！】" : "🔔【リマインダー】"
                content.body = "「\(item.title)」の時間です！今すぐ確認してください。"
            } else {
                content.title = "⚠️【未完了！超激震リマインダー】"
                content.body = "まだ完了していません！「\(item.title)」を忘れていませんか？"
            }
            
            // 1回目は音声読み上げ入り、2回目以降はサイレン（どちらもバイブ付き）
            let name = (offset == 0 || offset % 120 == 0) ? soundName : "alarm_siren.caf"
            content.sound = UNNotificationSound(named: UNNotificationSoundName(name))
            content.userInfo = [
                "reminderId": item.id.uuidString,
                "isGekiMode": item.isGekiMode,
                "taskTitle": item.title
            ]
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
            content.categoryIdentifier = "REMINDER_CATEGORY"
            
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(item.id.uuidString)_sec_\(offset)",
                content: content,
                trigger: trigger
            )
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                }
            }
        }
    }
    
    /// 指定されたリマインダーの通知・システムアラームをすべてキャンセル
    public func cancelNotification(for item: ReminderItem) {
        let center = UNUserNotificationCenter.current()
        let baseId = item.id.uuidString
        let identifiers = Self.gekiOffsetsInSeconds.map { "\(baseId)_sec_\($0)" }
            + Self.legacyOffsetsInMinutes.map { "\(baseId)_offset_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        SystemAlarmManager.shared.cancel(id: item.id)
    }
    
    // アプリがフォアグラウンドの時も通知を表示する
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }
    
    // 通知をタップした時およびクイックアクション選択時
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo["reminderId"] as? String,
              let uuid = UUID(uuidString: idString) else {
            completionHandler()
            return
        }
        
        switch response.actionIdentifier {
        case "COMPLETE_ACTION":
            DispatchQueue.main.async {
                ReminderStore.shared.toggleCompleted(id: uuid)
            }
        case "SNOOZE_1MIN":
            DispatchQueue.main.async {
                if let item = ReminderStore.shared.reminders.first(where: { $0.id == uuid }) {
                    var snoozed = item
                    snoozed.targetDate = Date().addingTimeInterval(60)
                    ReminderStore.shared.update(item: snoozed)
                }
            }
        case "OPEN_ALARM", UNNotificationDefaultActionIdentifier:
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenReminderFromNotification"),
                    object: nil,
                    userInfo: ["reminderId": uuid]
                )
            }
        default:
            break
        }
        
        completionHandler()
    }
}
