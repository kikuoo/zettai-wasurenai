import SwiftUI

@main
struct ZettaiWasurenaiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ReminderStore.shared
    
    var body: some Scene {
        WindowGroup {
            MainReminderListView()
                .onOpenURL { url in
                    if url.scheme == "zettaiwasurenai" {
                        if url.host == "alarm" || url.path == "/alarm" {
                            if let first = store.reminders.first(where: { !$0.isCompleted }) {
                                store.triggerAlarm(for: first)
                            }
                        } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                                  let idQuery = components.queryItems?.first(where: { $0.name == "id" })?.value,
                                  let uuid = UUID(uuidString: idQuery),
                                  let item = store.reminders.first(where: { $0.id == uuid && !$0.isCompleted }) {
                            store.triggerAlarm(for: item)
                        }
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // 通知デリゲート設定と権限確認
        NotificationManager.shared.checkAuthorization()
        SystemAlarmManager.shared.refreshAuthorization()
        
        // 既存の未完了予定を最新方式（音声入り通知・連続バイブ・システムアラーム）で再登録
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            for item in ReminderStore.shared.reminders where !item.isCompleted && item.locationTarget == nil && item.targetDate > Date() {
                NotificationManager.shared.scheduleNotification(for: item)
            }
        }
        return true
    }
}
