// InventoryItem.swift
// Inventory item model with structured affordances

import Foundation
import FirebaseFirestore
import CoreLocation

struct InventoryItem: Codable, Identifiable, Hashable {
    static func == (lhs: InventoryItem, rhs: InventoryItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    @DocumentID var id: String?
    
    var name: String
    var type: ItemType
    var accessMode: AccessMode
    var locationCoords: GeoPoint?
    var status: ItemStatus = .available
    var affordances: [Affordance] = []
    var temporalTags: TemporalTags?
    
    enum ItemType: String, Codable, CaseIterable {
        case tool
        case space
        case expert
    }
    
    enum AccessMode: String, Codable, CaseIterable {
        case owned
        case peer
        case rental
        case publicLibrary = "public_library"
    }
    
    enum ItemStatus: String, Codable {
        case available
        case booked
        case maintenance
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let coords = locationCoords else { return nil }
        return CLLocationCoordinate2D(latitude: coords.latitude, longitude: coords.longitude)
    }
}

// MARK: - Structured Affordance

struct Affordance: Codable, Equatable {
    var sense: Sense?
    var intensity: Intensity?
    var context: Context?
    var pleasureDimensions: [PleasureProfile.Dimension]?
    
    enum Sense: String, Codable, CaseIterable {
        case visual, auditory, olfactory, gustatory, tactile, kinesthetic, technical
    }
    
    enum Intensity: String, Codable, CaseIterable {
        case subtle, medium, high, overwhelming
    }
    
    enum Context: String, Codable, CaseIterable {
        case solitude, pair, smallGroup, crowd, mastery, drift, social
    }
    
    enum CodingKeys: String, CodingKey {
        case sense, intensity, context
        case pleasureDimensions = "pleasure_dims"
    }
}

// MARK: - Temporal Tags

struct TemporalTags: Codable, Equatable {
    var bestTimes: [CircadianProfile.TimeOfDay] = []
    var durationRange: DurationRange?
    var seasonal: [Season] = [.all]
    
    struct DurationRange: Codable, Equatable {
        var min: Int // minutes
        var max: Int
    }
    
    enum Season: String, Codable {
        case spring, summer, fall, winter, all
    }
    
    enum CodingKeys: String, CodingKey {
        case bestTimes = "best_times"
        case durationRange = "duration_range"
        case seasonal
    }
}
