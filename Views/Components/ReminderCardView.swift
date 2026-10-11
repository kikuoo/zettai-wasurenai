import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public struct ReminderCardView: View {
    public let item: ReminderItem
    public let onToggleComplete: () -> Void
    public let onTestAlarm: () -> Void
    public let onEdit: () -> Void
    public let onDelete: () -> Void
    
    public init(
        item: ReminderItem,
        onToggleComplete: @escaping () -> Void,
        onTestAlarm: @escaping () -> Void,
        onEdit: @escaping () -> Void = {},
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.onToggleComplete = onToggleComplete
        self.onTestAlarm = onTestAlarm
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 上段：チェック、カテゴリ、タイトル、アラームテスト
            HStack(alignment: .top, spacing: 12) {
                // 完了チェックボタン（老若男女が押しやすい大きめサイズ）
                Button(action: {
                    #if canImport(UIKit)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    #endif
                    onToggleComplete()
                }) {
                    ZStack {
                        Circle()
                            .stroke(item.isCompleted ? Color.green : Color.gray.opacity(0.35), lineWidth: 2.5)
                            .frame(width: 34, height: 34)
                        
                        if item.isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 34, height: 34)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                
                // 本文（タップで編集画面へ）
                Button(action: onEdit) {
                    HStack(alignment: .top, spacing: 10) {
                        // カテゴリアイコン
                        ZStack {
                            Circle()
                                .fill(item.category.color.opacity(item.isCompleted ? 0.15 : 0.2))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: item.category.iconName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(item.isCompleted ? .secondary : item.category.color)
                        }
                        
                        // 本文（タイトルと日時）
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                                    .strikethrough(item.isCompleted)
                                    .lineLimit(2)
                                
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.blue.opacity(0.8))
                            }
                            
                            HStack(spacing: 8) {
                                Label(item.formattedDateTime, systemImage: item.locationTarget != nil ? "mappin.circle.fill" : "clock.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(item.isOverdue ? .red : (item.locationTarget != nil ? .teal : .secondary))
                                
                                Text(item.formattedRemainingTime)
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(item.isCompleted ? Color.gray.opacity(0.15) : (item.locationTarget != nil ? Color.teal.opacity(0.15) : (item.isOverdue ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))))
                                    )
                                    .foregroundColor(item.isCompleted ? .secondary : (item.locationTarget != nil ? .teal : (item.isOverdue ? .red : .blue)))
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 鳴動テストボタン（未完了時）
                if !item.isCompleted {
                    Button(action: onTestAlarm) {
                        VStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("テスト")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // 下段：機能バッジ ＆ ダイレクト編集・削除ボタン
            HStack(spacing: 6) {
                // 場所バッジ（指定時）
                if let loc = item.locationTarget {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(loc.name)
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.teal.opacity(0.15)))
                    .foregroundColor(.teal)
                    .lineLimit(1)
                }
                
                if item.isGekiMode {
                    HStack(spacing: 3) {
                        Image(systemName: "bell.badge.fill")
                        Text("激震")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.red.opacity(0.15)))
                    .foregroundColor(.red)
                }
                
                if item.isVoiceAlert {
                    Image(systemName: "waveform")
                        .font(.system(size: 11, weight: .bold))
                        .padding(5)
                        .background(Circle().fill(Color.purple.opacity(0.15)))
                        .foregroundColor(.purple)
                }
                
                if item.isLightAlert {
                    Image(systemName: "flashlight.on.fill")
                        .font(.system(size: 11, weight: .bold))
                        .padding(5)
                        .background(Circle().fill(Color.orange.opacity(0.15)))
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                // 明示的な「編集」ボタン
                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("編集")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // 明示的な「削除」ボタン
                Button(action: onDelete) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                        Text("削除")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 46)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: item.isOverdue ? Color.red.opacity(0.08) : Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(item.isOverdue ? Color.red.opacity(0.4) : Color.clear, lineWidth: 1.5)
        )
    }
}
