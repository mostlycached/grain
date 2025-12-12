// InventoryService.swift
// Service for fetching, filtering, and managing inventory items

import Foundation
import CoreLocation
import Combine

@MainActor
final class InventoryService: ObservableObject {
    static let shared = InventoryService()
    
    @Published var items: [InventoryItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let firebase = FirebaseManager.shared
    
    private init() {}
    
    // MARK: - Fetch Operations
    
    /// Fetch all available inventory
    func fetchAll() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            items = try await firebase.fetchInventory()
        } catch {
            self.error = error
        }
    }
    
    /// Fetch inventory near a location
    func fetchNear(location: CLLocation, radiusMeters: Double = 5000) async -> [InventoryItem] {
        do {
            let allItems = try await firebase.fetchInventory()
            
            return allItems.filter { item in
                guard let itemCoord = item.coordinate else { return false }
                let itemLocation = CLLocation(latitude: itemCoord.latitude, longitude: itemCoord.longitude)
                return location.distance(from: itemLocation) <= radiusMeters
            }.sorted { item1, item2 in
                guard let coord1 = item1.coordinate, let coord2 = item2.coordinate else { return false }
                let loc1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
                let loc2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
                return location.distance(from: loc1) < location.distance(from: loc2)
            }
        } catch {
            self.error = error
            return []
        }
    }
    
    // MARK: - Filtering
    
    /// Filter by item type
    func filter(by type: InventoryItem.ItemType) -> [InventoryItem] {
        items.filter { $0.type == type }
    }
    
    /// Filter by access mode
    func filter(by accessMode: InventoryItem.AccessMode) -> [InventoryItem] {
        items.filter { $0.accessMode == accessMode }
    }
    
    /// Filter by pleasure dimensions
    func filter(by dimensions: [PleasureProfile.Dimension]) -> [InventoryItem] {
        items.filter { item in
            let itemDims = item.affordances.compactMap { $0.pleasureDimensions }.flatMap { $0 }
            return !Set(dimensions).isDisjoint(with: Set(itemDims))
        }
    }
    
    /// Filter by time of day suitability
    func filter(by timeOfDay: CircadianProfile.TimeOfDay) -> [InventoryItem] {
        items.filter { item in
            guard let temporal = item.temporalTags else { return true }
            return temporal.bestTimes.isEmpty || temporal.bestTimes.contains(timeOfDay)
        }
    }
    
    /// Filter available items only
    var availableItems: [InventoryItem] {
        items.filter { $0.status == .available }
    }
    
    // MARK: - Smart Recommendations
    
    /// Get items matching user's current state and circadian rhythm
    func recommendedItems(for user: User) -> [InventoryItem] {
        let currentTime = CircadianProfile.TimeOfDay.current()
        let preferredDims = user.circadianProfile.dimensions(for: currentTime)
        let stateDims = user.currentState.suggestedDimensions
        
        let allPreferred = Set(preferredDims + stateDims)
        
        return availableItems
            .map { item -> (item: InventoryItem, score: Int) in
                let itemDims = Set(item.affordances.compactMap { $0.pleasureDimensions }.flatMap { $0 })
                let overlap = itemDims.intersection(allPreferred).count
                return (item, overlap)
            }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map { $0.item }
    }
    
    /// Get items suitable for a specific session mode
    func items(for sessionState: SessionState) -> [InventoryItem] {
        let contextFilter: Affordance.Context
        switch sessionState {
        case .drift:
            contextFilter = .drift
        case .mastery:
            contextFilter = .mastery
        case .socialSync:
            contextFilter = .social
        default:
            return availableItems
        }
        
        return items.filter { item in
            item.affordances.contains { $0.context == contextFilter }
        }
    }
    
    // MARK: - Grouping
    
    /// Group items by type
    var itemsByType: [InventoryItem.ItemType: [InventoryItem]] {
        Dictionary(grouping: items, by: { $0.type })
    }
    
    /// Group items by access mode
    var itemsByAccess: [InventoryItem.AccessMode: [InventoryItem]] {
        Dictionary(grouping: items, by: { $0.accessMode })
    }
    
    /// Group available items by dominant pleasure dimension
    var itemsByDimension: [PleasureProfile.Dimension: [InventoryItem]] {
        var result: [PleasureProfile.Dimension: [InventoryItem]] = [:]
        
        for item in availableItems {
            let dims = item.affordances.compactMap { $0.pleasureDimensions }.flatMap { $0 }
            for dim in dims {
                result[dim, default: []].append(item)
            }
        }
        
        return result
    }
}
