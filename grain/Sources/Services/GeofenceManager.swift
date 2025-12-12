// GeofenceManager.swift
// Location monitoring and inventory proximity alerts

import Foundation
import CoreLocation
import UserNotifications

@MainActor
final class GeofenceManager: NSObject, ObservableObject {
    static let shared = GeofenceManager()
    
    @Published var nearbyItems: [InventoryItem] = []
    @Published var currentLocation: CLLocation?
    @Published var isMonitoring = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    private var monitoredItems: [String: InventoryItem] = [:] // regionId -> item
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = false
        setupNotifications()
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                try? await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            }
        }
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysPermission() {
        locationManager.requestAlwaysAuthorization()
    }
    
    // MARK: - Monitoring
    
    /// Start monitoring regions around inventory items
    func startMonitoring(items: [InventoryItem], radiusMeters: Double = 100) {
        // Clear existing regions
        stopMonitoring()
        
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            requestLocationPermission()
            return
        }
        
        // iOS limits to 20 monitored regions
        let itemsToMonitor = Array(items.filter { $0.coordinate != nil }.prefix(20))
        
        for item in itemsToMonitor {
            guard let coord = item.coordinate,
                  let itemId = item.id else { continue }
            
            let region = CLCircularRegion(
                center: coord,
                radius: radiusMeters,
                identifier: itemId
            )
            region.notifyOnEntry = true
            region.notifyOnExit = false
            
            monitoredItems[itemId] = item
            locationManager.startMonitoring(for: region)
        }
        
        locationManager.startUpdatingLocation()
        isMonitoring = true
    }
    
    func stopMonitoring() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredItems.removeAll()
        locationManager.stopUpdatingLocation()
        isMonitoring = false
    }
    
    /// Check which monitored items are nearby
    func updateNearbyItems() {
        guard let location = currentLocation else {
            nearbyItems = []
            return
        }
        
        nearbyItems = monitoredItems.values.filter { item in
            guard let coord = item.coordinate else { return false }
            let itemLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            return location.distance(from: itemLocation) <= 200 // 200m radius for "nearby"
        }.sorted { item1, item2 in
            guard let coord1 = item1.coordinate, let coord2 = item2.coordinate else { return false }
            let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
            let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
            return location.distance(from: loc1) < location.distance(from: loc2)
        }
    }
    
    // MARK: - Notifications
    
    private func sendProximityNotification(for item: InventoryItem) {
        let content = UNMutableNotificationContent()
        content.title = "Nearby Opportunity"
        content.body = "🌾 \(item.name) is nearby. Tap to explore."
        content.sound = .default
        
        // Add pleasure dimensions as subtitle if available
        let dims = item.affordances.compactMap { $0.pleasureDimensions }.flatMap { $0 }
        if !dims.isEmpty {
            content.subtitle = dims.prefix(2).map(\.displayName).joined(separator: ", ")
        }
        
        // Add item data for handling
        content.userInfo = [
            "itemId": item.id ?? "",
            "itemName": item.name,
            "type": "inventory_proximity"
        ]
        
        let request = UNNotificationRequest(
            identifier: "proximity_\(item.id ?? UUID().uuidString)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        Task {
            try? await notificationCenter.add(request)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension GeofenceManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let loc = location // Copy before crossing boundary
        Task { @MainActor in
            self.currentLocation = loc
            self.updateNearbyItems()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        let regionId = circularRegion.identifier // Copy before crossing boundary
        
        Task { @MainActor in
            if let item = self.monitoredItems[regionId] {
                self.sendProximityNotification(for: item)
                
                // Add to nearby if not already present
                if !self.nearbyItems.contains(where: { $0.id == item.id }) {
                    self.nearbyItems.insert(item, at: 0)
                }
            }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        let regionId = circularRegion.identifier // Copy before crossing boundary
        
        Task { @MainActor in
            self.nearbyItems.removeAll { $0.id == regionId }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus // Copy before crossing boundary
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error)")
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Region monitoring failed: \(error)")
    }
}
