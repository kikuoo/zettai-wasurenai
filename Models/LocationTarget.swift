import Foundation
import CoreLocation

/// 場所によるリマインダー通知設定
public struct LocationTarget: Codable, Equatable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var radius: Double // 半径 (メートル)
    public var notifyOnEntry: Bool // 到着時
    public var notifyOnExit: Bool  // 出発時
    
    public init(
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 100.0,
        notifyOnEntry: Bool = true,
        notifyOnExit: Bool = false
    ) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.notifyOnEntry = notifyOnEntry
        self.notifyOnExit = notifyOnExit
    }
    
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    public var summaryText: String {
        var action = ""
        if notifyOnEntry && notifyOnExit {
            action = "到着または出発時"
        } else if notifyOnEntry {
            action = "到着時"
        } else if notifyOnExit {
            action = "出発時"
        }
        return "📍 \(name) 付近 (\(action))"
    }
}
