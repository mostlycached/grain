// PlannerService.swift
// Service for generating missions using Gemini

import Foundation
import CoreLocation

@MainActor
final class PlannerService: ObservableObject {
    static let shared = PlannerService()
    
    @Published var currentMission: Mission?
    @Published var isGenerating = false
    @Published var error: Error?
    
    private let gemini = GeminiService.shared
    private let inventory = InventoryService.shared
    
    private init() {}
    
    // MARK: - Mission Generation
    
    /// Generate a mission based on user state and available inventory
    func generateMission(
        for user: GrainUser,
        duration: MissionDuration = .medium,
        location: String = "NYC"
    ) async throws -> Mission {
        isGenerating = true
        defer { isGenerating = false }
        
        // Get recommended items
        let recommendedItems = inventory.recommendedItems(for: user)
        let itemsContext = formatItemsForPrompt(Array(recommendedItems.prefix(10)))
        
        // Get circadian context
        let timeOfDay = CircadianProfile.TimeOfDay.current()
        let preferredDims = user.circadianProfile.dimensions(for: timeOfDay)
        
        let prompt = """
        Generate a \(duration.description) hedonic mission for someone in \(location).
        
        USER STATE: \(user.currentState.rawValue)
        TIME OF DAY: \(timeOfDay.rawValue)
        PREFERRED DIMENSIONS: \(preferredDims.map(\.displayName).joined(separator: ", "))
        
        AVAILABLE INVENTORY:
        \(itemsContext)
        
        Generate a mission that:
        1. Matches the user's current energy state
        2. Activates 2-3 of the preferred pleasure dimensions
        3. Uses available inventory when possible
        4. Is specific to \(location) locations
        
        Respond in this exact JSON format:
        {
            "title": "Short evocative title",
            "description": "2-3 sentences describing the experience phenomenologically",
            "duration": "\(duration.description)",
            "location": "Specific location name",
            "dimensions": ["dimension1", "dimension2"],
            "inventoryIds": ["id1", "id2"],
            "steps": ["step1", "step2", "step3"]
        }
        """
        
        let response = try await gemini.generateText(
            prompt: prompt,
            systemPrompt: Self.plannerSystemPrompt
        )
        
        let mission = try parseMissionResponse(response, items: recommendedItems)
        currentMission = mission
        return mission
    }
    
    /// Generate a quick spontaneous mission
    func generateQuickMission(near location: CLLocationCoordinate2D) async throws -> Mission {
        isGenerating = true
        defer { isGenerating = false }
        
        let prompt = """
        Generate a spontaneous 15-minute hedonic micro-mission.
        The user is at coordinates: \(location.latitude), \(location.longitude)
        
        Focus on immediate sensory engagement with whatever is around them.
        Emphasize: texture, sound, breath, movement.
        
        Respond in JSON format:
        {
            "title": "Short title",
            "description": "1-2 sentences",
            "duration": "15 mins",
            "location": "Your current location",
            "dimensions": ["serendipity_following", "mobility"],
            "steps": ["step1", "step2"]
        }
        """
        
        let response = try await gemini.generateText(prompt: prompt)
        let mission = try parseMissionResponse(response, items: [])
        currentMission = mission
        return mission
    }
    
    // MARK: - Private Helpers
    
    private static let plannerSystemPrompt = """
    You are The Architect, a hedonic mission planner within the grain system.
    You design experiences that activate specific pleasure dimensions.
    
    The 16 dimensions are:
    - Spatial: order, enclosure, path, horizon
    - Cognitive: anxiety, ignorance, repetition
    - Temporal: post
    - Embodied: food, mobility, erotic_uncertainty, material_play
    - Relational: power, nature_mirror, serendipity_following, anchor_expansion
    
    Always respond with valid JSON. Be specific about locations and sensory details.
    """
    
    private func formatItemsForPrompt(_ items: [InventoryItem]) -> String {
        items.map { item in
            let dims = item.affordances.compactMap { $0.pleasureDimensions }.flatMap { $0 }
            return "- \(item.name) (\(item.type.rawValue), \(item.accessMode.rawValue)): \(dims.map(\.rawValue).joined(separator: ", "))"
        }.joined(separator: "\n")
    }
    
    private func parseMissionResponse(_ response: String, items: [InventoryItem]) throws -> Mission {
        // Extract JSON from response (may be wrapped in markdown)
        let jsonString = extractJSON(from: response)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw PlannerError.invalidResponse
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        guard let json = json,
              let title = json["title"] as? String,
              let description = json["description"] as? String else {
            throw PlannerError.invalidResponse
        }
        
        let dimensionStrings = json["dimensions"] as? [String] ?? []
        let dimensions = dimensionStrings.compactMap { str in
            PleasureProfile.Dimension.allCases.first { $0.rawValue == str || $0.displayName.lowercased() == str.lowercased() }
        }
        
        let inventoryIds = json["inventoryIds"] as? [String] ?? []
        let matchedItems = items.filter { inventoryIds.contains($0.id ?? "") }
        
        return Mission(
            title: title,
            description: description,
            duration: json["duration"] as? String ?? "30 mins",
            location: json["location"] as? String ?? "Your location",
            dimensions: dimensions,
            inventoryItems: matchedItems,
            steps: json["steps"] as? [String] ?? []
        )
    }
    
    private func extractJSON(from text: String) -> String {
        // Try to find JSON block in markdown
        if let jsonStart = text.range(of: "{"),
           let jsonEnd = text.range(of: "}", options: .backwards) {
            return String(text[jsonStart.lowerBound...jsonEnd.upperBound])
        }
        return text
    }
}

// MARK: - Supporting Types

struct Mission: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let duration: String
    let location: String
    let dimensions: [PleasureProfile.Dimension]
    var inventoryItems: [InventoryItem] = []
    var steps: [String] = []
    var scheduledDate: Date?
    
    static func == (lhs: Mission, rhs: Mission) -> Bool {
        lhs.id == rhs.id
    }
}

enum MissionDuration: String, CaseIterable {
    case quick = "15 mins"
    case medium = "30 mins"
    case extended = "1 hour"
    case deep = "2+ hours"
    
    var description: String { rawValue }
    
    var minutes: Int {
        switch self {
        case .quick: return 15
        case .medium: return 30
        case .extended: return 60
        case .deep: return 120
        }
    }
}

enum PlannerError: Error, LocalizedError {
    case invalidResponse
    case noInventoryAvailable
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Could not parse mission response"
        case .noInventoryAvailable: return "No inventory items available"
        }
    }
}

