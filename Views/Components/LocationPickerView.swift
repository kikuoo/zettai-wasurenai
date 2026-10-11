import SwiftUI
import MapKit
import CoreLocation

/// 地図上で通知場所（ピン・半径・条件）を指定するビュー
public struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var locationManager = LocationManager.shared
    
    @Binding var locationTarget: LocationTarget?
    
    @State private var locationName: String = ""
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.681236, longitude: 139.767125), // 東京駅デフォルト
        span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
    )
    @State private var radius: Double = 100.0
    @State private var notifyOnEntry: Bool = true
    @State private var notifyOnExit: Bool = false
    
    // 定番の場所プリセット
    private let commonPlaces = ["自宅", "会社・職場", "最寄り駅", "スーパー", "学校", "病院"]
    
    public init(locationTarget: Binding<LocationTarget?>) {
        self._locationTarget = locationTarget
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 地図表示エリア
                ZStack {
                    Map(coordinateRegion: $region, showsUserLocation: true)
                        .edgesIgnoringSafeArea(.all)
                    
                    // 中央の固定ピン（地図を動かして位置を決める直感UI）
                    VStack(spacing: 0) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.red)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 3)
                        
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 14, height: 6)
                    }
                    .offset(y: -18)
                    
                    // 現在地ボタン
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: moveToCurrentLocation) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 20))
                                    .padding(12)
                                    .background(Color.white)
                                    .foregroundColor(.blue)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
                .frame(maxHeight: 280)
                
                // 設定パネル
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        
                        // 場所の名前
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1. 場所の名前")
                                .font(.system(size: 16, weight: .bold))
                            
                            // ワンタッププリセット
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(commonPlaces, id: \.self) { place in
                                        Button(action: { locationName = place }) {
                                            Text(place)
                                                .font(.system(size: 13, weight: .semibold))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(locationName == place ? Color.blue : Color(UIColor.secondarySystemGroupedBackground))
                                                .foregroundColor(locationName == place ? .white : .primary)
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                        }
                                    }
                                }
                            }
                            
                            TextField("例: 自宅、渋谷駅、スーパー", text: $locationName)
                                .font(.system(size: 16))
                                .padding(12)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // 通知するタイミング
                        VStack(alignment: .leading, spacing: 8) {
                            Text("2. お知らせするタイミング")
                                .font(.system(size: 16, weight: .bold))
                            
                            HStack(spacing: 12) {
                                Button(action: { notifyOnEntry.toggle() }) {
                                    HStack {
                                        Image(systemName: notifyOnEntry ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(notifyOnEntry ? .green : .secondary)
                                        Text("到着した時")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(notifyOnEntry ? Color.green.opacity(0.12) : Color(UIColor.secondarySystemGroupedBackground))
                                    .foregroundColor(notifyOnEntry ? .green : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(notifyOnEntry ? Color.green : Color.gray.opacity(0.2), lineWidth: 1))
                                }
                                
                                Button(action: { notifyOnExit.toggle() }) {
                                    HStack {
                                        Image(systemName: notifyOnExit ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(notifyOnExit ? .blue : .secondary)
                                        Text("出発した時")
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(notifyOnExit ? Color.blue.opacity(0.12) : Color(UIColor.secondarySystemGroupedBackground))
                                    .foregroundColor(notifyOnExit ? .blue : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(notifyOnExit ? Color.blue : Color.gray.opacity(0.2), lineWidth: 1))
                                }
                            }
                        }
                        
                        // 範囲（半径）
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("3. 反応する範囲（半径）")
                                    .font(.system(size: 16, weight: .bold))
                                Spacer()
                                Text("\(Int(radius))m")
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundColor(.blue)
                            }
                            
                            Slider(value: $radius, in: 50...500, step: 25)
                                .tint(.blue)
                        }
                        
                        // 決定ボタン
                        Button(action: saveLocation) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("この場所を設定する")
                                    .font(.system(size: 17, weight: .heavy))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.top, 4)
                        
                        // 場所設定を解除するボタン
                        if locationTarget != nil {
                            Button(action: {
                                locationTarget = nil
                                dismiss()
                            }) {
                                Text("場所の設定を解除する")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(20)
                }
                .background(Color(UIColor.systemGroupedBackground))
            }
            .navigationTitle("場所を指定する")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear {
                locationManager.requestAuthorization()
                if let current = locationTarget {
                    locationName = current.name
                    region.center = current.coordinate
                    radius = current.radius
                    notifyOnEntry = current.notifyOnEntry
                    notifyOnExit = current.notifyOnExit
                } else if let userLoc = locationManager.userLocation {
                    region.center = userLoc
                }
            }
        }
    }
    
    private func moveToCurrentLocation() {
        locationManager.requestCurrentLocation()
        if let userLoc = locationManager.userLocation {
            withAnimation {
                region.center = userLoc
            }
        }
    }
    
    private func saveLocation() {
        let finalName = locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "指定の場所" : locationName
        locationTarget = LocationTarget(
            name: finalName,
            latitude: region.center.latitude,
            longitude: region.center.longitude,
            radius: radius,
            notifyOnEntry: notifyOnEntry,
            notifyOnExit: notifyOnExit
        )
        dismiss()
    }
}
