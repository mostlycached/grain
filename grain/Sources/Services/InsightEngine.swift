// InsightEngine.swift
// Generates insights from session patterns using vector similarity and Gemini

import Foundation

@MainActor
final class InsightEngine: ObservableObject {
    static let shared = InsightEngine()
    
    @Published var latestInsight: Insight?
    @Published var isGenerating = false
    
    private let gemini = GeminiService.shared
    private let vectorService = VectorService.shared
    private let firebase = FirebaseManager.shared
    
    private init() {}
    
    // MARK: - Insight Generation
    
    /// Generate insight by comparing current session to similar past sessions
    func generateSessionInsight(for session: Session) async throws -> Insight {
        isGenerating = true
        defer { isGenerating = false }
        
        // Find similar past sessions
        let embedding = vectorService.generateEmbedding(from: session)
        let similarSessions = try await vectorService.findSimilarViaFirebase(to: embedding, limit: 5)
        
        guard !similarSessions.isEmpty else {
            return Insight(
                type: .pattern,
                summary: "This is a new type of experience for you. Keep exploring!",
                dimensions: session.pleasureVector?.dominantDimensions ?? [],
                relatedSessionIds: [],
                generatedAt: Date()
            )
        }
        
        // Format context for Gemini
        let prompt = formatSessionComparisonPrompt(current: session, similar: similarSessions)
        
        let response = try await gemini.generateText(
            prompt: prompt,
            systemPrompt: Self.insightSystemPrompt
        )
        
        let insight = parseInsightResponse(
            response,
            dimensions: session.pleasureVector?.dominantDimensions ?? [],
            relatedIds: similarSessions.compactMap { $0.id }
        )
        
        latestInsight = insight
        return insight
    }
    
    /// Generate weekly insight from multiple sessions
    func generateWeeklyInsight(from sessions: [Session]) async throws -> Insight {
        isGenerating = true
        defer { isGenerating = false }
        
        guard !sessions.isEmpty else {
            return Insight(
                type: .weekly,
                summary: "Start some sessions to get weekly insights!",
                dimensions: [],
                relatedSessionIds: [],
                generatedAt: Date()
            )
        }
        
        // Analyze patterns
        let clusters = vectorService.clusterSessions(sessions)
        let variance = vectorService.dimensionVariance(in: sessions)
        let centroid = vectorService.centroid(of: sessions)
        let dominantDims = vectorService.dominantDimensions(in: centroid)
        
        // Find most and least explored dimensions
        let sortedVariance = variance.enumerated().sorted { $0.element > $1.element }
        let mostVaried = sortedVariance.prefix(3).map { PleasureProfile.Dimension.allCases[$0.offset] }
        let leastVaried = sortedVariance.suffix(3).map { PleasureProfile.Dimension.allCases[$0.offset] }
        
        let prompt = formatWeeklyPrompt(
            sessions: sessions,
            clusters: clusters,
            dominantDims: dominantDims,
            mostVaried: mostVaried,
            leastVaried: leastVaried
        )
        
        let response = try await gemini.generateText(
            prompt: prompt,
            systemPrompt: Self.insightSystemPrompt
        )
        
        let insight = Insight(
            type: .weekly,
            summary: response,
            dimensions: dominantDims,
            relatedSessionIds: sessions.compactMap { $0.id },
            generatedAt: Date(),
            metadata: [
                "sessionCount": "\(sessions.count)",
                "clusterCount": "\(clusters.count)",
                "mostVaried": mostVaried.map(\.displayName).joined(separator: ", "),
                "leastVaried": leastVaried.map(\.displayName).joined(separator: ", ")
            ]
        )
        
        latestInsight = insight
        return insight
    }
    
    /// Generate suggestion for next session based on patterns
    func generateNextSessionSuggestion(userId: String) async throws -> Insight {
        isGenerating = true
        defer { isGenerating = false }
        
        let sessions = try await firebase.fetchSessions(userId: userId)
        let recentSessions = Array(sessions.prefix(10))
        
        guard !recentSessions.isEmpty else {
            return Insight(
                type: .suggestion,
                summary: "Try starting with a Drift session to explore freely.",
                dimensions: [.serendipityFollowing, .mobility],
                relatedSessionIds: [],
                generatedAt: Date()
            )
        }
        
        // Find underexplored dimensions
        let centroid = vectorService.centroid(of: recentSessions)
        let underexplored = PleasureProfile.Dimension.allCases.enumerated().filter { index, _ in
            index < centroid.count && centroid[index] < 0.2
        }.map { $0.element }
        
        // Get user's circadian preferences for current time
        let timeOfDay = CircadianProfile.TimeOfDay.current()
        let user = try await getCurrentUser()
        let circadianDims = user?.circadianProfile.dimensions(for: timeOfDay) ?? []
        
        let prompt = """
        Based on the user's recent sessions, suggest a new experience.
        
        UNDEREXPLORED DIMENSIONS: \(underexplored.map { $0.displayName }.joined(separator: ", "))
        CURRENT TIME PREFERENCES: \(circadianDims.map(\.displayName).joined(separator: ", "))
        RECENT SESSION COUNT: \(recentSessions.count)
        
        Suggest ONE specific activity that activates underexplored dimensions 
        while respecting their current time-of-day preferences.
        Keep suggestion to 2-3 sentences. Be specific and evocative.
        """
        
        let response = try await gemini.generateText(prompt: prompt)
        
        let suggestedDims = underexplored.isEmpty ? circadianDims : Array(underexplored.prefix(2))
        
        return Insight(
            type: .suggestion,
            summary: response,
            dimensions: suggestedDims,
            relatedSessionIds: [],
            generatedAt: Date()
        )
    }
    
    // MARK: - Private Helpers
    
    private static let insightSystemPrompt = """
    You are The Scribe, an insight generator within the grain hedonic operating system.
    Your role is to identify patterns in pleasure experiences and offer phenomenological observations.
    
    The 16 pleasure dimensions are:
    - Spatial: order, enclosure, path, horizon
    - Cognitive: anxiety (productive tension), ignorance (mystery), repetition (ritual)
    - Temporal: post (appreciation of aftermath)
    - Embodied: food, mobility, erotic_uncertainty, material_play
    - Relational: power, nature_mirror, serendipity_following, anchor_expansion
    
    Keep insights concise (2-4 sentences). Be evocative, not clinical.
    Focus on patterns, not judgments. Invite curiosity.
    """
    
    private func formatSessionComparisonPrompt(current: Session, similar: [Session]) -> String {
        let currentDims = (current.pleasureVector?.dominantDimensions ?? []).map { $0.displayName }.joined(separator: ", ")
        
        let similarDescriptions = similar.enumerated().map { index, session in
            let dims = (session.pleasureVector?.dominantDimensions ?? []).map { $0.displayName }.joined(separator: ", ")
            let date = session.timestampStart.formatted(date: .abbreviated, time: .omitted)
            return "Session \(index + 1) (\(date)): \(dims)"
        }.joined(separator: "\n")
        
        return """
        The user just completed a session with these activated dimensions:
        \(currentDims)
        
        Here are their most similar past sessions:
        \(similarDescriptions)
        
        Identify a pattern or insight connecting these experiences.
        What might they be exploring? What's emerging?
        """
    }
    
    private func formatWeeklyPrompt(
        sessions: [Session],
        clusters: [[Session]],
        dominantDims: [PleasureProfile.Dimension],
        mostVaried: [PleasureProfile.Dimension],
        leastVaried: [PleasureProfile.Dimension]
    ) -> String {
        return """
        Weekly pleasure pattern analysis:
        
        TOTAL SESSIONS: \(sessions.count)
        DISTINCT PATTERNS (clusters): \(clusters.count)
        DOMINANT DIMENSIONS: \(dominantDims.map(\.displayName).joined(separator: ", "))
        MOST VARIED: \(mostVaried.map(\.displayName).joined(separator: ", "))
        LEAST EXPLORED: \(leastVaried.map(\.displayName).joined(separator: ", "))
        
        Provide a 3-4 sentence insight about this week's pleasure patterns.
        Note any emerging themes, suggest one dimension to explore more.
        """
    }
    
    private func parseInsightResponse(
        _ response: String,
        dimensions: [PleasureProfile.Dimension],
        relatedIds: [String]
    ) -> Insight {
        Insight(
            type: .pattern,
            summary: response,
            dimensions: dimensions,
            relatedSessionIds: relatedIds,
            generatedAt: Date()
        )
    }
    
    private func getCurrentUser() async throws -> User? {
        return firebase.currentUser
    }
}

// MARK: - Insight Model

struct Insight: Identifiable {
    let id = UUID()
    let type: InsightType
    let summary: String
    let dimensions: [PleasureProfile.Dimension]
    let relatedSessionIds: [String]
    let generatedAt: Date
    var metadata: [String: String] = [:]
}

enum InsightType: String, Codable {
    case pattern = "pattern"
    case weekly = "weekly"
    case suggestion = "suggestion"
    case milestone = "milestone"
}
