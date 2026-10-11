import SwiftUI

public struct SettingsView: View {
    @ObservedObject var store: ReminderStore
    @ObservedObject var subManager = SubscriptionManager.shared
    @ObservedObject var notifManager = NotificationManager.shared
    @ObservedObject var flashManager = FlashlightManager.shared
    @ObservedObject var speechManager = SpeechManager.shared
    @ObservedObject var soundManager = SoundEffectManager.shared
    @ObservedObject var alarmManager = SystemAlarmManager.shared
    
    @State private var isTestingFlash: Bool = false
    @State private var showBulkDeleteConfirm: Bool = false
    @State private var bulkDeleteResult: String? = nil
    @State private var showPaywallSheet: Bool = false
    @State private var restoreMessage: String? = nil
    @State private var showRestoreAlert: Bool = false
    
    public init(store: ReminderStore) {
        self.store = store
    }
    
    private func guideRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    public var body: some View {
        NavigationView {
            List {
                // MARK: - 0. プレミアムプラン / サブスクリプション
                Section(header: Text("ご利用プラン").font(.system(size: 14, weight: .bold))) {
                    if subManager.isPro {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 22))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("プレミアムプラン")
                                            .font(.system(size: 17, weight: .bold))
                                        Text("有効")
                                            .font(.system(size: 11, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.green.opacity(0.15))
                                            .foregroundColor(.green)
                                            .clipShape(Capsule())
                                    }
                                    Text("やること登録無制限・定番追加・場所通知が使い放題です")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider().padding(.vertical, 4)
                            
                            Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                                HStack {
                                    Label("サブスクリプションの確認・解約", systemImage: "arrow.up.forward.app")
                                        .font(.system(size: 14, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.15))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 20))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("無料プラン")
                                        .font(.system(size: 17, weight: .bold))
                                    Text("やること登録は最大3件まで（現在 \(store.reminders.filter { !$0.isCompleted }.count)/3件）")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Button(action: {
                                showPaywallSheet = true
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("プレミアムに登録（月額300円）")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange, Color.red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // 購入を復元ボタン
                    Button(action: {
                        Task {
                            await subManager.restorePurchases()
                            if subManager.isPro {
                                restoreMessage = "購入情報を復元しました。プレミアム機能をご利用いただけます。"
                            } else {
                                restoreMessage = "有効なサブスクリプションが見つかりませんでした。"
                            }
                            showRestoreAlert = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("購入情報を復元する")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }
                
                // 1. 通知許可ステータス
                Section(header: Text("通知の設定").font(.system(size: 14, weight: .bold))) {
                    HStack {
                        Image(systemName: notifManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(notifManager.isAuthorized ? .green : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(notifManager.isAuthorized ? "通知は許可されています" : "通知がオフになっています")
                                .font(.system(size: 16, weight: .semibold))
                            Text(notifManager.isAuthorized ? "指定時刻に音と画面でお知らせします" : "確実に気づくため通知を許可してください")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !notifManager.isAuthorized {
                            Button("許可する") {
                                notifManager.requestAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // システムアラーム（AlarmKit）
                if alarmManager.isSupported {
                    Section(
                        header: Text("システムアラーム（激震モード）").font(.system(size: 14, weight: .bold)),
                        footer: Text("許可すると、激震モードの予定は時計アプリのアラームと同じ扱いになり、ロック中・他アプリ使用中・マナーモード中でも止めるまで鳴り続けます。").font(.system(size: 12))
                    ) {
                        HStack {
                            Image(systemName: alarmManager.isAuthorized ? "alarm.fill" : "alarm")
                                .font(.system(size: 22))
                                .foregroundColor(alarmManager.isAuthorized ? .green : .orange)
                            Text(alarmManager.isAuthorized ? "アラームは許可されています" : "アラームが未許可です")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            if !alarmManager.isAuthorized {
                                Button("許可する") {
                                    alarmManager.requestAuthorization { granted in
                                        if granted {
                                            store.reminders.forEach { NotificationManager.shared.scheduleNotification(for: $0) }
                                        } else if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 画面ロック中・他アプリ使用中のお知らせ
                Section(
                    header: Text("ロック中・他アプリ使用中のお知らせ").font(.system(size: 14, weight: .bold)),
                    footer: Text("※カメラライトの点滅はiOSの制限により、アプリが開いていない間はアプリから直接操作できません。代わりにiPhone本体の「LEDフラッシュ通知」を使います。").font(.system(size: 12))
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        guideRow(icon: "bell.and.waves.left.and.right.fill", color: .red,
                                 title: "通知・サイレン・バイブ",
                                 detail: "激震モードでは0秒〜10分後まで最大10回くり返し通知し、そのたびにサイレンとバイブが鳴ります。")
                        Divider()
                        guideRow(icon: "waveform", color: .purple,
                                 title: "音声読み上げ",
                                 detail: "「○○の時間です」という声を通知音に録音しているため、アプリを開いていなくても声でお知らせします。")
                        Divider()
                        guideRow(icon: "flashlight.on.fill", color: .orange,
                                 title: "ライト点滅（本体設定が必要）",
                                 detail: "「設定」>「アクセシビリティ」>「オーディオ/ビジュアル」>「LEDフラッシュ通知」をON。さらに「ロック解除中に点滅」もONにすると、他のアプリを使っている時も光ります。")
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("iPhoneの設定を開く", systemImage: "gear")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .buttonStyle(.bordered)
                        .padding(.leading, 34)
                        Divider()
                        guideRow(icon: "speaker.slash.fill", color: .gray,
                                 title: "マナーモード中の注意",
                                 detail: "通常の通知はマナーモードで音が消えます。マナーモード中でも鳴らしたい場合は、上の「システムアラーム」を許可して激震モードを使ってください。")
                    }
                    .padding(.vertical, 8)
                }
                
                // データ管理（完了したやることの一括削除）
                Section(
                    header: Text("データの整理").font(.system(size: 14, weight: .bold)),
                    footer: Text("未完了のやることは削除されません。").font(.system(size: 12))
                ) {
                    Button(role: .destructive, action: { showBulkDeleteConfirm = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("完了したやることを一括削除")
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text("\(store.completedCount)件")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(store.completedCount == 0 ? .secondary : .red)
                    }
                    .disabled(store.completedCount == 0)
                    .confirmationDialog(
                        "完了したやること\(store.completedCount)件を削除しますか？",
                        isPresented: $showBulkDeleteConfirm,
                        titleVisibility: .visible
                    ) {
                        Button("\(store.completedCount)件をすべて削除する", role: .destructive) {
                            let count = store.deleteAllCompleted()
                            #if canImport(UIKit)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            #endif
                            bulkDeleteResult = "\(count)件の完了したやることを削除しました"
                        }
                        Button("キャンセル", role: .cancel) {}
                    } message: {
                        Text("この操作は取り消せません。")
                    }
                    
                    if let result = bulkDeleteResult {
                        Label(result, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
                
                // 2. 激震アラーム体験テスト（音・光・音声）
                Section(
                    header: Text("音と光・音声の体験テスト").font(.system(size: 14, weight: .bold)),
                    footer: Text("カメラライトや大音量サイレン、音声が正常に鳴るか手元でテストできます。").font(.system(size: 12))
                ) {
                    // フルアラーム体験
                    Button(action: {
                        let sample = ReminderItem(
                            title: "お薬を飲む時間です！",
                            category: .medicine,
                            targetDate: Date(),
                            isGekiMode: true,
                            isVoiceAlert: true,
                            isLightAlert: true
                        )
                        store.triggerAlarm(for: sample)
                    }) {
                        HStack {
                            Label("🚨 激震モードをフル体験する", systemImage: "bolt.heart.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 光（カメラフラッシュ）テスト
                    HStack {
                        Label("カメラライト点滅テスト", systemImage: "flashlight.on.fill")
                            .foregroundColor(.orange)
                        
                        Spacer()
                        
                        Button(flashManager.isFlashing ? "停止" : "点滅開始") {
                            if flashManager.isFlashing {
                                flashManager.stopStrobeFlash()
                            } else {
                                flashManager.startStrobeFlash()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }
                    
                    // 音声読み上げテスト
                    HStack {
                        Label("音声読み上げテスト", systemImage: "waveform")
                            .foregroundColor(.purple)
                        
                        Spacer()
                        
                        Button(speechManager.isSpeaking ? "停止" : "再生") {
                            if speechManager.isSpeaking {
                                speechManager.stop()
                            } else {
                                speechManager.speak(text: "絶対に忘れないでください！やることの時間です！")
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    }
                    
                    // アラーム音テスト
                    HStack {
                        Label("サイレンアラーム音テスト", systemImage: "bell.badge.fill")
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button(soundManager.isAlarmPlaying ? "停止" : "再生") {
                            if soundManager.isAlarmPlaying {
                                soundManager.stopAlarm()
                            } else {
                                soundManager.startIntenseAlarm()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                
                // 3. ウィジェットの案内
                Section(header: Text("ホーム画面ウィジェット").font(.system(size: 14, weight: .bold))) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ホーム画面でいつでも確認")
                                    .font(.system(size: 16, weight: .bold))
                                Text("直近のやること・残り時間をひと目で確認できます")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text("【設置方法】ホーム画面の余白を長押し ➔ 左上の「＋」ボタン ➔ 「絶対忘れない！」を選択して追加してください。")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 6)
                }
                
                // 4. アプリ情報
                Section(header: Text("アプリ情報").font(.system(size: 14, weight: .bold))) {
                    HStack {
                        Text("アプリ名")
                        Spacer()
                        Text("絶対忘れない！リマインダー")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("設定とテスト")
            .sheet(isPresented: $showPaywallSheet) {
                PaywallView()
            }
            .alert("購入の復元", isPresented: $showRestoreAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }
}
