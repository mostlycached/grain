// VectorService.swift
// 16D pleasure vector embeddings and similarity operations

import Foundation

@MainActor
final class VectorService: ObservableObject {
    static let shared = VectorService()
    
    private let firebase = FirebaseManager.shared
    
    private init() {}
    
    // MARK: - Embedding Generation
    
    /// Generate 16D pleasure embedding from session data
    func generateEmbedding(from session: Session) -> [Double] {
        var vector = Array(repeating: 0.0, count: 16)
        
        // Use activated dimensions and their intensities
        for (dim, intensity) in session.pleasureVector?.activatedDimensions ?? [:] {
            if let index = PleasureProfile.Dimension.allCases.firstIndex(of: dim) {
                vector[index] = intensity
            }
        }
        
        // Normalize vector to unit length for cosine similarity
        return normalize(vector)
    }
    
    /// Generate embedding from user's overall pleasure profile
    func generateEmbedding(from profile: PleasureProfile) -> [Double] {
        let vector = profile.toVector()
        return normalize(vector)
    }
    
    /// Generate embedding from a mission's target dimensions
    func generateEmbedding(from mission: Mission) -> [Double] {
        var vector = Array(repeating: 0.0, count: 16)
        
        for dim in mission.dimensions {
            if let index = PleasureProfile.Dimension.allCases.firstIndex(of: dim) {
                vector[index] = 1.0
            }
        }
        
        return normalize(vector)
    }
    
    // MARK: - Similarity Operations
    
    /// Calculate cosine similarity between two vectors
    func cosineSimilarity(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count, !v1.isEmpty else { return 0 }
        
        var dotProduct = 0.0
        var norm1 = 0.0
        var norm2 = 0.0
        
        for i in 0..<v1.count {
            dotProduct += v1[i] * v2[i]
            norm1 += v1[i] * v1[i]
            norm2 += v2[i] * v2[i]
        }
        
        let denominator = sqrt(norm1) * sqrt(norm2)
        return denominator > 0 ? dotProduct / denominator : 0
    }
    
    /// Calculate Euclidean distance between two vectors
    func euclideanDistance(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count else { return Double.infinity }
        
        var sum = 0.0
        for i in 0..<v1.count {
            let diff = v1[i] - v2[i]
            sum += diff * diff
        }
        
        return sqrt(sum)
    }
    
    /// Find k most similar sessions to a query vector
    func findSimilar(to queryVector: [Double], in sessions: [Session], k: Int = 5) -> [Session] {
        let scored = sessions.compactMap { session -> (session: Session, score: Double)? in
            let embedding = session.pleasureVector?.embedding ?? []
            guard !embedding.isEmpty else { return nil }
            let score = cosineSimilarity(queryVector, embedding)
            return (session, score)
        }
        
        return scored
            .sorted { $0.score > $1.score }
            .prefix(k)
            .map { $0.session }
    }
    
    /// Find sessions using Firebase Vector Search
    func findSimilarViaFirebase(to queryVector: [Double], limit: Int = 10) async throws -> [Session] {
        return try await firebase.findSimilarSessions(vector: queryVector, limit: limit)
    }
    
    // MARK: - Dimension Analysis
    
    /// Get the dominant dimensions from a vector
    func dominantDimensions(in vector: [Double], threshold: Double = 0.3) -> [PleasureProfile.Dimension] {
        return PleasureProfile.Dimension.allCases.enumerated().compactMap { index, dim in
            guard index < vector.count, vector[index] >= threshold else { return nil }
            return dim
        }
    }
    
    /// Calculate the "center" of multiple session vectors
    func centroid(of sessions: [Session]) -> [Double] {
        guard !sessions.isEmpty else { return Array(repeating: 0.0, count: 16) }
        
        var sum = Array(repeating: 0.0, count: 16)
        var count = 0
        
        for session in sessions {
            let embedding = session.pleasureVector?.embedding ?? []
            guard embedding.count == 16 else { continue }
            
            for i in 0..<16 {
                sum[i] += embedding[i]
            }
            count += 1
        }
        
        guard count > 0 else { return sum }
        return sum.map { $0 / Double(count) }
    }
    
    /// Calculate variance in each dimension across sessions
    func dimensionVariance(in sessions: [Session]) -> [Double] {
        let center = centroid(of: sessions)
        guard !sessions.isEmpty else { return Array(repeating: 0.0, count: 16) }
        
        var variance = Array(repeating: 0.0, count: 16)
        var count = 0
        
        for session in sessions {
            let embedding = session.pleasureVector?.embedding ?? []
            guard embedding.count == 16 else { continue }
            
            for i in 0..<16 {
                let diff = embedding[i] - center[i]
                variance[i] += diff * diff
            }
            count += 1
        }
        
        guard count > 0 else { return variance }
        return variance.map { $0 / Double(count) }
    }
    
    // MARK: - Helpers
    
    private func normalize(_ vector: [Double]) -> [Double] {
        let magnitude = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }
}

// MARK: - Dimension Clustering

extension VectorService {
    /// Cluster sessions by their pleasure signatures
    func clusterSessions(_ sessions: [Session], numClusters: Int = 4) -> [[Session]] {
        guard sessions.count >= numClusters else {
            return [sessions]
        }
        
        // Simple k-means-like clustering
        var centroids = Array(sessions.shuffled().prefix(numClusters)).map { s in
            let emb = s.pleasureVector?.embedding ?? []
            return emb.isEmpty ? Array(repeating: 0.0, count: 16) : emb
        }
        
        var clusters: [[Session]] = Array(repeating: [], count: numClusters)
        
        // Run a few iterations
        for _ in 0..<10 {
            clusters = Array(repeating: [], count: numClusters)
            
            // Assign sessions to nearest centroid
            for session in sessions {
                let embedding = session.pleasureVector?.embedding ?? []
                guard !embedding.isEmpty else { continue }
                
                var bestCluster = 0
                var bestDistance = Double.infinity
                
                for (i, centroid) in centroids.enumerated() {
                    let distance = euclideanDistance(session.pleasureVector?.embedding ?? [], centroid)
                    if distance < bestDistance {
                        bestDistance = distance
                        bestCluster = i
                    }
                }
                
                clusters[bestCluster].append(session)
            }
            
            // Update centroids
            for i in 0..<numClusters {
                if !clusters[i].isEmpty {
                    centroids[i] = centroid(of: clusters[i])
                }
            }
        }
        
        return clusters.filter { !$0.isEmpty }
    }
}
