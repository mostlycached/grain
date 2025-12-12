// Session.swift
// Session model with state history and pleasure vector

import Foundation
import FirebaseFirestore

struct Session: Codable, Identifiable {
    @DocumentID var id: String?
    
    var userId: String
    var state: SessionState = .idle
    var stateHistory: [SessionState] = []
    var timestampStart: Date = Date()
    var timestampEnd: Date?
    var transcriptUrl: String?
    var mediaUrls: [String] = []
    var pleasureVector: SessionPleasureVector?
    var notes: String?
    var embeddingId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case state
        case stateHistory = "state_history"
        case timestampStart = "timestamp_start"
        case timestampEnd = "timestamp_end"
        case transcriptUrl = "transcript_url"
        case mediaUrls = "media_urls"
        case pleasureVector = "pleasure_vector"
        case notes
        case embeddingId = "embedding_id"
    }
    
    var duration: TimeInterval? {
        guard let end = timestampEnd else { return nil }
        return end.timeIntervalSince(timestampStart)
    }
    
    mutating func transition(to newState: SessionState) {
        stateHistory.append(state)
        state = newState
    }
}

// MARK: - Session Pleasure Vector

struct SessionPleasureVector: Codable, Equatable {
    var primary: [PleasureProfile.Dimension] = []
    var secondary: [PleasureProfile.Dimension] = []
    var intensities: [PleasureProfile.Dimension: Double] = [:]
    var embedding: [Double] = []
    var activatedDimensions: [PleasureProfile.Dimension: Double] = [:]
    
    static func == (lhs: SessionPleasureVector, rhs: SessionPleasureVector) -> Bool {
        lhs.embedding == rhs.embedding && lhs.primary == rhs.primary
    }
    
    func toVector() -> [Double] {
        if !embedding.isEmpty {
            return embedding
        }
        return PleasureProfile.Dimension.allCases.map { intensities[$0] ?? 0.0 }
    }
    
    var dominantDimensions: [PleasureProfile.Dimension] {
        // Return dimensions with intensity > 0.3, sorted by intensity
        activatedDimensions
            .filter { $0.value > 0.3 }
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }
    
    var dominantDimension: PleasureProfile.Dimension? {
        dominantDimensions.first ?? primary.first
    }
    
    mutating func activate(_ dimension: PleasureProfile.Dimension, intensity: Double = 0.7) {
        activatedDimensions[dimension] = intensity
        if !primary.contains(dimension) && intensity > 0.5 {
            primary.append(dimension)
        }
    }
}

// MARK: - Session State

enum SessionState: String, Codable, CaseIterable {
    case idle
    case drift
    case mastery
    case socialSync = "social_sync"
    case reflection
    
    var displayName: String {
        switch self {
        case .socialSync: return "Social Sync"
        default: return rawValue.capitalized
        }
    }
    
    var systemColor: String {
        switch self {
        case .idle: return "gray"
        case .drift: return "purple"
        case .mastery: return "orange"
        case .socialSync: return "blue"
        case .reflection: return "green"
        }
    }
    
    /// Valid transitions from this state
    var validTransitions: [SessionState] {
        switch self {
        case .idle:
            return [.drift]
        case .drift:
            return [.mastery, .socialSync, .reflection]
        case .mastery:
            return [.drift, .socialSync, .reflection]
        case .socialSync:
            return [.drift, .mastery, .reflection]
        case .reflection:
            return [.idle]
        }
    }
    
    func canTransition(to target: SessionState) -> Bool {
        validTransitions.contains(target)
    }
}
