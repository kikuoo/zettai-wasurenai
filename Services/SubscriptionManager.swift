import Foundation
import StoreKit
import SwiftUI

/// アプリ内課金（StoreKit 2）およびプレミアムサブスクリプション管理
@MainActor
public final class SubscriptionManager: ObservableObject {
    public static let shared = SubscriptionManager()
    
    /// 月額サブスクリプションの製品ID
    public static let monthlySubscriptionID = "com.zettaiwasurenai.app.subscription.monthly"
    
    /// 無料プランで登録可能な未完了やることの最大数
    public static let freeReminderLimit = 3
    
    /// プレミアム会員（Pro）状態
    @Published public private(set) var isPro: Bool = false
    
    /// 取得したサブスクリプション製品
    @Published public private(set) var monthlyProduct: Product? = nil
    
    /// 処理中フラグ
    @Published public var isLoading: Bool = false
    
    /// エラーメッセージ
    @Published public var errorMessage: String? = nil
    
    private var updatesTask: Task<Void, Never>? = nil
    
    private init() {
        // バックグラウンドでのトランザクション更新（自動更新、別端末での購入など）を監視
        updatesTask = listenForTransactionUpdates()
        
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    // MARK: - 商品情報の取得
    
    public func requestProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.monthlySubscriptionID])
            self.monthlyProduct = products.first
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    // MARK: - 購入処理
    
    public func purchaseMonthly() async -> Bool {
        guard let product = monthlyProduct else {
            errorMessage = "商品情報を取得できませんでした。通信環境をご確認ください。"
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateCustomerProductStatus()
                return isPro
            case .userCancelled:
                return false
            case .pending:
                errorMessage = "購入処理が保留中です。承認をお待ちください。"
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "購入処理中にエラーが発生しました: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - 購入の復元（Restore）
    
    public func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await updateCustomerProductStatus()
        } catch {
            errorMessage = "復元処理中にエラーが発生しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 現在の会員権限の確認
    
    public func updateCustomerProductStatus() async {
        var hasActivePro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.monthlySubscriptionID {
                    if transaction.revocationDate == nil {
                        hasActivePro = true
                    }
                }
            }
        }
        self.isPro = hasActivePro
    }
    
    // MARK: - トランザクション監視
    
    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.updateCustomerProductStatus()
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - 開発・テスト用（プレビューなどで即時Pro切り替え可能）
    #if DEBUG
    public func toggleProForDebug() {
        isPro.toggle()
    }
    #endif
}
