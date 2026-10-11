import Foundation
import SwiftUI

#if canImport(AlarmKit)
import AlarmKit
import AppIntents
#endif

/// iOS 26.1以降の「AlarmKit」を利用し、時計アプリのアラームと同じ扱いで鳴らすマネージャー。
/// ・画面ロック中 / 他アプリ操作中 / マナーモード中 / 集中モード中でも、止めるまで鳴り続けます。
/// ・iOS 26.1未満の端末では何もしません（通常の通知のみで動作）。
public final class SystemAlarmManager: ObservableObject {
    public static let shared = SystemAlarmManager()
    
    @Published public private(set) var isSupported: Bool = false
    @Published public private(set) var isAuthorized: Bool = false
    
    private init() {
        if #available(iOS 26.1, *) {
            isSupported = true
            refreshAuthorization()
        }
    }
    
    // MARK: - 権限
    
    public func refreshAuthorization() {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            let state = AlarmManager.shared.authorizationState
            DispatchQueue.main.async { self.isAuthorized = (state == .authorized) }
        }
        #endif
    }
    
    public func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            Task {
                let state = (try? await AlarmManager.shared.requestAuthorization()) ?? .denied
                await MainActor.run {
                    self.isAuthorized = (state == .authorized)
                    completion?(self.isAuthorized)
                }
            }
            return
        }
        #endif
        completion?(false)
    }
    
    // MARK: - スケジュール / キャンセル
    
    /// 時間指定・未完了・激震モードのリマインダーをシステムアラームとして登録
    public func schedule(for item: ReminderItem) {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            cancel(id: item.id)
            guard !item.isCompleted,
                  item.locationTarget == nil,
                  item.isGekiMode,
                  item.targetDate > Date() else { return }
            
            Task {
                // 未許可なら一度だけ許可を求める
                if AlarmManager.shared.authorizationState == .notDetermined {
                    _ = try? await AlarmManager.shared.requestAuthorization()
                }
                guard AlarmManager.shared.authorizationState == .authorized else { return }
                
                let openButton = AlarmButton(
                    text: "アプリで確認",
                    textColor: .white,
                    systemImageName: "bell.badge.fill"
                )
                let alert = AlarmPresentation.Alert(
                    title: LocalizedStringResource(stringLiteral: "🚨 \(item.title)"),
                    secondaryButton: openButton,
                    secondaryButtonBehavior: .custom
                )
                let attributes = AlarmAttributes<ReminderAlarmMetadata>(
                    presentation: AlarmPresentation(alert: alert),
                    metadata: ReminderAlarmMetadata(reminderId: item.id.uuidString),
                    tintColor: .red
                )
                let configuration = AlarmManager.AlarmConfiguration<ReminderAlarmMetadata>.alarm(
                    schedule: .fixed(item.targetDate),
                    attributes: attributes,
                    secondaryIntent: OpenReminderAlarmIntent(reminderId: item.id.uuidString),
                    sound: .named("alarm_siren.caf")
                )
                do {
                    _ = try await AlarmManager.shared.schedule(id: item.id, configuration: configuration)
                } catch {
                    print("AlarmKit schedule error: \(error)")
                }
            }
        }
        #endif
    }
    
    public func cancel(id: UUID) {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            try? AlarmManager.shared.cancel(id: id)
        }
        #endif
    }
}

#if canImport(AlarmKit)
@available(iOS 26.0, *)
public struct ReminderAlarmMetadata: AlarmMetadata {
    public var reminderId: String
    public init(reminderId: String) { self.reminderId = reminderId }
}

/// アラーム画面の「アプリで確認」ボタン → アプリを開いて音声・光・サイレンのフル警告を発動
@available(iOS 26.0, *)
public struct OpenReminderAlarmIntent: LiveActivityIntent {
    public static var title: LocalizedStringResource = "アラームを開く"
    public static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Reminder ID")
    public var reminderId: String
    
    public init() { self.reminderId = "" }
    public init(reminderId: String) { self.reminderId = reminderId }
    
    @MainActor
    public func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: reminderId),
           let item = ReminderStore.shared.reminders.first(where: { $0.id == uuid && !$0.isCompleted }) {
            ReminderStore.shared.triggerAlarm(for: item)
        }
        return .result()
    }
}
#endif
