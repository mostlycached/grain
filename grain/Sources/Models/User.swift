// User.swift
// User model with pleasure profile and session state

import Foundation
import FirebaseFirestore

struct GrainUser: Codable, Identifiable {
    @DocumentID var id: String?
    
    var pleasureProfile: PleasureProfile = PleasureProfile()
    var circadianProfile: CircadianProfile = CircadianProfile()
    var currentState: UserState = .neutral
    var sessionState: SessionState = .idle
    var context: String = "nyc"
    
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    enum UserState: String, Codable, CaseIterable {
        case depleted
        case anxious
        case scattered
        case neutral
        case curious
        case energized
        case flowing
        
        var suggestedDimensions: [PleasureProfile.Dimension] {
            switch self {
            case .depleted:
                return [.food, .enclosure, .repetition]
            case .anxious:
                return [.order, .path, .natureMirror]
            case .scattered:
                return [.enclosure, .repetition, .anchorExpansion]
            case .neutral:
                return [.serendipityFollowing, .mobility]
            case .curious:
                return [.ignorance, .horizon, .serendipityFollowing]
            case .energized:
                return [.mobility, .power, .materialPlay]
            case .flowing:
                return [.post, .natureMirror, .eroticUncertainty]
            }
        }
    }
}
