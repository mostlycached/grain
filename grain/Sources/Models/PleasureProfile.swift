// PleasureProfile.swift
// 16-dimensional compositional pleasure profile

import Foundation

/// The 16 compositional pleasure dimensions used throughout grain
struct PleasureProfile: Codable, Equatable {
    
    // MARK: - Spatial/Environmental
    
    /// Satisfaction from structure, organization
    var order: Double = 0.5
    
    /// Preference for contained vs. expansive spaces
    var enclosure: Double = 0.5
    
    /// Joy in route-finding, directed movement
    var path: Double = 0.5
    
    /// Drawn to vistas, big-picture views
    var horizon: Double = 0.5
    
    // MARK: - Cognitive/Existential
    
    /// Tolerance/appetite for productive tension
    var anxiety: Double = 0.5
    
    /// Comfort with not-knowing, mystery
    var ignorance: Double = 0.5
    
    /// Pleasure in ritual, recurrence
    var repetition: Double = 0.5
    
    // MARK: - Temporal
    
    /// Appreciation of aftermath, reflection
    var post: Double = 0.5
    
    // MARK: - Embodied
    
    /// Gustatory pleasure sensitivity
    var food: Double = 0.5
    
    /// Kinesthetic joy, movement
    var mobility: Double = 0.5
    
    /// Attraction to ambiguous intimacy
    var eroticUncertainty: Double = 0.5
    
    /// Tactile exploration, making
    var materialPlay: Double = 0.5
    
    // MARK: - Relational/External
    
    /// Agency, influence, mastery over
    var power: Double = 0.5
    
    /// Resonance with natural systems
    var natureMirror: Double = 0.5
    
    /// Openness to chance encounters
    var serendipityFollowing: Double = 0.5
    
    /// Building from stable points outward
    var anchorExpansion: Double = 0.5
    
    // MARK: - Dimension Enumeration
    
    enum Dimension: String, CaseIterable, Codable {
        case order, enclosure, path, horizon
        case anxiety, ignorance, repetition
        case post
        case food, mobility, eroticUncertainty, materialPlay
        case power, natureMirror, serendipityFollowing, anchorExpansion
        
        var category: Category {
            switch self {
            case .order, .enclosure, .path, .horizon:
                return .spatialEnvironmental
            case .anxiety, .ignorance, .repetition:
                return .cognitiveExistential
            case .post:
                return .temporal
            case .food, .mobility, .eroticUncertainty, .materialPlay:
                return .embodied
            case .power, .natureMirror, .serendipityFollowing, .anchorExpansion:
                return .relationalExternal
            }
        }
        
        var displayName: String {
            switch self {
            case .eroticUncertainty: return "Erotic Uncertainty"
            case .materialPlay: return "Material Play"
            case .natureMirror: return "Nature Mirror"
            case .serendipityFollowing: return "Serendipity Following"
            case .anchorExpansion: return "Anchor Expansion"
            default: return rawValue.capitalized
            }
        }
    }
    
    enum Category: String, CaseIterable {
        case spatialEnvironmental = "Spatial/Environmental"
        case cognitiveExistential = "Cognitive/Existential"
        case temporal = "Temporal"
        case embodied = "Embodied"
        case relationalExternal = "Relational/External"
    }
    
    // MARK: - Accessors
    
    subscript(dimension: Dimension) -> Double {
        get {
            switch dimension {
            case .order: return order
            case .enclosure: return enclosure
            case .path: return path
            case .horizon: return horizon
            case .anxiety: return anxiety
            case .ignorance: return ignorance
            case .repetition: return repetition
            case .post: return post
            case .food: return food
            case .mobility: return mobility
            case .eroticUncertainty: return eroticUncertainty
            case .materialPlay: return materialPlay
            case .power: return power
            case .natureMirror: return natureMirror
            case .serendipityFollowing: return serendipityFollowing
            case .anchorExpansion: return anchorExpansion
            }
        }
        set {
            switch dimension {
            case .order: order = newValue
            case .enclosure: enclosure = newValue
            case .path: path = newValue
            case .horizon: horizon = newValue
            case .anxiety: anxiety = newValue
            case .ignorance: ignorance = newValue
            case .repetition: repetition = newValue
            case .post: post = newValue
            case .food: food = newValue
            case .mobility: mobility = newValue
            case .eroticUncertainty: eroticUncertainty = newValue
            case .materialPlay: materialPlay = newValue
            case .power: power = newValue
            case .natureMirror: natureMirror = newValue
            case .serendipityFollowing: serendipityFollowing = newValue
            case .anchorExpansion: anchorExpansion = newValue
            }
        }
    }
    
    /// Returns as 16-dimensional vector for embedding
    func toVector() -> [Double] {
        Dimension.allCases.map { self[$0] }
    }
    
    /// Top activated dimensions (above threshold)
    func activatedDimensions(threshold: Double = 0.6) -> [Dimension] {
        Dimension.allCases.filter { self[$0] >= threshold }
            .sorted { self[$0] > self[$1] }
    }
}
