// GeminiService.swift
// Gemini API service via Firebase Cloud Functions (secure backend proxy)

import Foundation
import FirebaseFunctions

/// Service for interacting with Gemini via Firebase Cloud Functions
/// The API key is stored securely in Cloud Functions, NOT in the client
@MainActor
final class GeminiService: ObservableObject {
    static let shared = GeminiService()
    
    @Published var isConnected = false
    @Published var lastResponse: String?
    
    private lazy var functions = Functions.functions()
    
    private init() {}
    
    // MARK: - System Prompts
    
    static let somaticCoachPrompt = """
    You are a somatic coach within the grain hedonic operating system. 
    Focus on the 16 pleasure dimensions: Order, Anxiety, Post, Enclosure, Path, Horizon, 
    Ignorance, Repetition, Food, Mobility, Power, Erotic Uncertainty, Material Play, 
    Nature Mirror, Serendipity Following, Anchor Expansion.
    
    Guide the user's attention to:
    - Texture and tactile qualities
    - Breath and body awareness  
    - Spatial relationships and horizons
    - Movement possibilities
    
    Keep responses brief (1-2 sentences) and phenomenologically precise.
    Speak in a calm, inviting tone that encourages exploration.
    """
    
    static let visionAnalysisPrompt = """
    Analyze this image through a phenomenological lens.
    Identify the dominant pleasure dimensions present (from the 16 dimensions).
    Provide a brief (1-2 sentence) instruction on how to engage with what you see.
    Reference specific textures, colors, spatial qualities, or affordances.
    """
    
    // MARK: - Text Generation (via Cloud Function)
    
    /// Send text to Gemini via Cloud Function
    func generateText(prompt: String, systemPrompt: String = somaticCoachPrompt) async throws -> String {
        let data: [String: Any] = [
            "prompt": prompt,
            "systemPrompt": systemPrompt,
            "model": "gemini-2.0-flash"
        ]
        
        let result = try await functions.httpsCallable("callGemini").call(data)
        
        guard let response = result.data as? [String: Any],
              let text = response["text"] as? String else {
            throw GeminiError.invalidResponse
        }
        
        lastResponse = text
        return text
    }
    
    // MARK: - Vision Analysis (via Cloud Function)
    
    /// Analyze image via Cloud Function
    func analyzeImage(_ imageData: Data, prompt: String = visionAnalysisPrompt) async throws -> String {
        let base64Image = imageData.base64EncodedString()
        
        let data: [String: Any] = [
            "image": base64Image,
            "mimeType": "image/jpeg",
            "prompt": prompt,
            "model": "gemini-2.0-flash"
        ]
        
        let result = try await functions.httpsCallable("analyzeImage").call(data)
        
        guard let response = result.data as? [String: Any],
              let text = response["text"] as? String else {
            throw GeminiError.invalidResponse
        }
        
        return text
    }
    
    // MARK: - Live Session (via Cloud Function with streaming)
    
    /// Start a live coaching session via Cloud Function
    /// For real-time voice, the client records audio locally and sends chunks
    func sendVoiceMessage(_ audioData: Data, sessionId: String) async throws -> LiveResponse {
        let base64Audio = audioData.base64EncodedString()
        
        let data: [String: Any] = [
            "audio": base64Audio,
            "mimeType": "audio/wav",
            "sessionId": sessionId,
            "systemPrompt": Self.somaticCoachPrompt
        ]
        
        let result = try await functions.httpsCallable("processVoice").call(data)
        
        guard let response = result.data as? [String: Any] else {
            throw GeminiError.invalidResponse
        }
        
        return LiveResponse(
            text: response["text"] as? String,
            audioBase64: response["audio"] as? String,
            detectedDimensions: response["dimensions"] as? [String] ?? []
        )
    }
    
    func connect() {
        isConnected = true
    }
    
    func disconnect() {
        isConnected = false
        lastResponse = nil
    }
}

// MARK: - Response Types

struct LiveResponse {
    let text: String?
    let audioBase64: String? // TTS audio from Gemini
    let detectedDimensions: [String]
}

// MARK: - Error Types

enum GeminiError: Error, LocalizedError {
    case invalidResponse
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Gemini"
        case .notConnected: return "Not connected to Gemini service"
        }
    }
}
