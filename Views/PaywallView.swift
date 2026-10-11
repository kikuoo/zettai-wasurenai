import SwiftUI
import StoreKit

/// プレミアムプラン（月額300円）の案内＆課金シート（Paywall）
public struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subManager = SubscriptionManager.shared
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - ヘッダーアイコン & タイトル
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.yellow, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 6)
                            
                            Image(systemName: "crown.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 10)
                        
                        Text("プレミアムプラン")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(.primary)
                        
                        Text("すべての制限を解除して、\n絶対に忘れない安心をあなたに。")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - 3大特典リスト
                    VStack(spacing: 14) {
                        featureRow(
                            icon: "infinity",
                            iconColor: .blue,
                            title: "やること登録が無制限",
                            subtitle: "無料プランは3件まで。プレミアムなら何件でも安心して予定を登録できます。"
                        )
                        
                        featureRow(
                            icon: "plus.circle.fill",
                            iconColor: .purple,
                            title: "自分だけの「定番」ボタンを追加",
                            subtitle: "「犬の散歩」「換気」「プロテイン」など、よくやることを無制限にワンタップ登録。"
                        )
                        
                        featureRow(
                            icon: "mappin.and.ellipse",
                            iconColor: .teal,
                            title: "場所でお知らせ（地図指定）",
                            subtitle: "「会社に着いたら連絡」「駅を出たら買い物」など、指定場所への到着・出発で通知。"
                        )
                    }
                    .padding(18)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
                    
                    // MARK: - 料金カード
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("月額プラン")
                                    .font(.system(size: 18, weight: .bold))
                                Text("自動更新サブスクリプション")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("¥300")
                                    .font(.system(size: 32, weight: .heavy))
                                    .foregroundColor(.blue)
                                Text("/ 月")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.blue.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // エラーメッセージ表示
                    if let err = subManager.errorMessage {
                        Text(err)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                    }
                    
                    // MARK: - 購入ボタン
                    VStack(spacing: 12) {
                        Button(action: {
                            Task {
                                let success = await subManager.purchaseMonthly()
                                if success {
                                    dismiss()
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                if subManager.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                    Text("月額300円で登録する")
                                        .font(.system(size: 18, weight: .heavy))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color(red: 0.1, green: 0.4, blue: 0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .disabled(subManager.isLoading)
                        
                        // 購入の復元ボタン
                        Button(action: {
                            Task {
                                await subManager.restorePurchases()
                                if subManager.isPro {
                                    dismiss()
                                }
                            }
                        }) {
                            Text("以前購入された方はこちら（購入を復元）")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - 規約・サブスクリプション説明（Apple審査必須要件）
                    VStack(spacing: 8) {
                        Text("【サブスクリプションについて】\n・お支払いは購入確認時にお客様のApple IDアカウントに請求されます。\n・現在の期間が終了する少なくとも24時間前までに自動更新をオフにしない限り、サブスクリプションは自動的に更新されます。\n・購読の管理や自動更新の停止は、購入後にiPhoneの「設定」>「Apple Account」>「サブスクリプション」からいつでも行えます。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        HStack(spacing: 16) {
                            Link("利用規約 (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                            
                            Text("・")
                                .foregroundColor(.secondary)
                            
                            Link("プライバシーポリシー", destination: URL(string: "https://zettaiwasurenai.app/privacy")!)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
    
    private func featureRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}
