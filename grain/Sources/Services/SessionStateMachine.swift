// SessionStateMachine.swift
// Observable state machine for session transitions

import Foundation
import Combine

/// Manages session state transitions: idle → drift ↔ mastery ↔ social_sync → reflection
@MainActor
final class SessionStateMachine: ObservableObject {
    static let shared = SessionStateMachine()
    
    @Published private(set) var currentState: SessionState = .idle
    @Published private(set) var stateHistory: [SessionState] = []
    @Published private(set) var currentSession: Session?
    @Published var activePleasureDimensions: [PleasureProfile.Dimension] = []
    
    private var sessionStartTime: Date?
    
    // MARK: - State Transitions
    
    func transition(to targetState: SessionState) throws {
        guard currentState.canTransition(to: targetState) else {
            throw StateMachineError.invalidTransition(from: currentState, to: targetState)
        }
        
        stateHistory.append(currentState)
        currentState = targetState
        
        // Update current session if active
        currentSession?.transition(to: targetState)
        
        // Handle special state entries
        switch targetState {
        case .drift:
            if sessionStartTime == nil {
                sessionStartTime = Date()
            }
        case .reflection:
            // Session is ending
            break
        case .idle:
            // Reset for next session
            reset()
        default:
            break
        }
    }
    
    // MARK: - Session Management
    
    func startSession(userId: String) async throws {
        guard currentState == .idle else {
            throw StateMachineError.sessionAlreadyActive
        }
        
        // Create session in Firebase
        let session = try await FirebaseManager.shared.createSession(userId: userId)
        currentSession = session
        sessionStartTime = Date()
        
        // Transition to drift
        try transition(to: .drift)
    }
    
    func endSession() async throws {
        guard currentState != .idle else { return }
        
        // Calculate pleasure vector from active dimensions
        let pleasureVector = calculatePleasureVector()
        
        // Transition to reflection
        try transition(to: .reflection)
        
        // Save to Firebase
        if let session = currentSession {
            try await FirebaseManager.shared.endSession(session, pleasureVector: pleasureVector)
        }
        
        // Then to idle
        try transition(to: .idle)
    }
    
    func reset() {
        stateHistory.removeAll()
        currentSession = nil
        sessionStartTime = nil
        activePleasureDimensions.removeAll()
    }
    
    // MARK: - Pleasure Dimension Tracking
    
    func activateDimension(_ dimension: PleasureProfile.Dimension) {
        if !activePleasureDimensions.contains(dimension) {
            activePleasureDimensions.append(dimension)
        }
    }
    
    func deactivateDimension(_ dimension: PleasureProfile.Dimension) {
        activePleasureDimensions.removeAll { $0 == dimension }
    }
    
    private func calculatePleasureVector() -> SessionPleasureVector {
        var vector = SessionPleasureVector()
        
        // Top 3 are primary
        vector.primary = Array(activePleasureDimensions.prefix(3))
        
        // Rest are secondary
        if activePleasureDimensions.count > 3 {
            vector.secondary = Array(activePleasureDimensions.dropFirst(3))
        }
        
        // Calculate intensities based on how long each was active
        // (simplified: equal intensity for now)
        for dim in activePleasureDimensions {
            let index = activePleasureDimensions.firstIndex(of: dim)!
            let intensity = 1.0 - (Double(index) * 0.1)
            vector.intensities[dim] = max(0.3, intensity)
        }
        
        return vector
    }
    
    // MARK: - Computed Properties
    
    var sessionDuration: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
    
    var isSessionActive: Bool {
        currentState != .idle
    }
    
    var canEnterMastery: Bool {
        currentState.canTransition(to: .mastery)
    }
    
    var canEnterSocialSync: Bool {
        currentState.canTransition(to: .socialSync)
    }
}

// MARK: - Errors

enum StateMachineError: Error, LocalizedError {
    case invalidTransition(from: SessionState, to: SessionState)
    case sessionAlreadyActive
    case noActiveSession
    
    var errorDescription: String? {
        switch self {
        case .invalidTransition(let from, let to):
            return "Cannot transition from \(from.displayName) to \(to.displayName)"
        case .sessionAlreadyActive:
            return "A session is already active"
        case .noActiveSession:
            return "No active session"
        }
    }
}

