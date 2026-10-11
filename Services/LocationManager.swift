import Foundation
import CoreLocation
import MapKit
import UserNotifications

/// 地図・場所によるリマインダーと位置情報を管理するマネージャー
public final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    @Published public var userLocation: CLLocationCoordinate2D?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// 位置情報権限のリクエスト
    public func requestAuthorization() {
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }
    
    /// 現在地の即時更新を開始
    public func requestCurrentLocation() {
        locationManager.requestLocation()
    }
    
    // MARK: - ジオフェンス（場所通知）のスケジュール
    
    public func scheduleLocationNotification(for item: ReminderItem) {
        guard let loc = item.locationTarget, !item.isCompleted else { return }
        
        let center = UNUserNotificationCenter.current()
        let identifier = "\(item.id.uuidString)_location"
        
        // 既存の場所通知を削除
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let coordinate = loc.coordinate
        let region = CLCircularRegion(
            center: coordinate,
            radius: loc.radius,
            identifier: identifier
        )
        region.notifyOnEntry = loc.notifyOnEntry
        region.notifyOnExit = loc.notifyOnExit
        
        let content = UNMutableNotificationContent()
        content.title = item.isGekiMode ? "🚨【指定場所に到着！絶対に忘れないで！】" : "📍【場所のリマインダー】"
        content.body = "「\(item.title)」の時間・場所です！(\(loc.name)付近)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("alarm_siren.caf"))
        content.categoryIdentifier = "REMINDER_CATEGORY"
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            "reminderId": item.id.uuidString,
            "isGekiMode": item.isGekiMode,
            "taskTitle": item.title
        ]
        
        let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Location notification scheduling error: \(error)")
            }
        }
    }
    
    public func cancelLocationNotification(for item: ReminderItem) {
        let identifier = "\(item.id.uuidString)_location"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if self.authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.userLocation = loc.coordinate
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }
}
