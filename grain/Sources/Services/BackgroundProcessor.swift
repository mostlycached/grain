// BackgroundProcessor.swift
// Background task scheduler for deferred audio uploads and session processing

import Foundation
import BackgroundTasks
import UIKit

@MainActor
final class BackgroundProcessor {
    static let shared = BackgroundProcessor()
    
    // Task identifiers
    static let audioUploadTaskId = "com.grain.audioUpload"
    static let sessionProcessingTaskId = "com.grain.sessionProcessing"
    static let insightGenerationTaskId = "com.grain.insightGeneration"
    
    private let firebase = FirebaseManager.shared
    
    private init() {}
    
    // MARK: - Registration
    
    /// Call this from AppDelegate's didFinishLaunching
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.audioUploadTaskId,
            using: nil
        ) { task in
            self.handleAudioUploadTask(task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.sessionProcessingTaskId,
            using: nil
        ) { task in
            self.handleSessionProcessingTask(task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.insightGenerationTaskId,
            using: nil
        ) { task in
            self.handleInsightGenerationTask(task as! BGProcessingTask)
        }
    }
    
    // MARK: - Scheduling
    
    /// Schedule audio upload for when device is charging
    func scheduleAudioUpload() {
        let request = BGProcessingTaskRequest(identifier: Self.audioUploadTaskId)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true // Upload when charging
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Scheduled audio upload task")
        } catch {
            print("Failed to schedule audio upload: \(error)")
        }
    }
    
    /// Schedule session processing for overnight
    func scheduleSessionProcessing() {
        let request = BGProcessingTaskRequest(identifier: Self.sessionProcessingTaskId)
        request.requiresNetworkConnectivity = true
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // At least 1 hour from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Scheduled session processing task")
        } catch {
            print("Failed to schedule session processing: \(error)")
        }
    }
    
    /// Schedule insight generation
    func scheduleInsightGeneration() {
        let request = BGProcessingTaskRequest(identifier: Self.insightGenerationTaskId)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Scheduled insight generation task")
        } catch {
            print("Failed to schedule insight generation: \(error)")
        }
    }
    
    // MARK: - Task Handlers
    
    private func handleAudioUploadTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                try await uploadPendingAudioFiles()
                task.setTaskCompleted(success: true)
            } catch {
                print("Audio upload failed: \(error)")
                task.setTaskCompleted(success: false)
            }
            
            // Reschedule for next time
            scheduleAudioUpload()
        }
    }
    
    private func handleSessionProcessingTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                try await processUnprocessedSessions()
                task.setTaskCompleted(success: true)
            } catch {
                print("Session processing failed: \(error)")
                task.setTaskCompleted(success: false)
            }
            
            scheduleSessionProcessing()
        }
    }
    
    private func handleInsightGenerationTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                try await generateWeeklyInsights()
                task.setTaskCompleted(success: true)
            } catch {
                print("Insight generation failed: \(error)")
                task.setTaskCompleted(success: false)
            }
            
            scheduleInsightGeneration()
        }
    }
    
    // MARK: - Background Operations
    
    /// Upload pending audio files to Firebase Storage
    private func uploadPendingAudioFiles() async throws {
        let pendingDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending_audio")
        
        guard FileManager.default.fileExists(atPath: pendingDir.path) else { return }
        
        let files = try FileManager.default.contentsOfDirectory(
            at: pendingDir,
            includingPropertiesForKeys: nil
        )
        
        for file in files where file.pathExtension == "wav" || file.pathExtension == "m4a" {
            let data = try Data(contentsOf: file)
            let path = "users/\(firebase.currentUser?.id ?? "anonymous")/audio/\(file.lastPathComponent)"
            
            // Upload to Firebase Storage
            // Note: This would use Firebase Storage API
            print("Would upload \(file.lastPathComponent) to \(path)")
            
            // Clean up local file after upload
            try FileManager.default.removeItem(at: file)
        }
    }
    
    /// Process sessions that need vector embeddings
    private func processUnprocessedSessions() async throws {
        guard let userId = firebase.currentUser?.id else { return }
        
        let sessions = try await firebase.fetchSessions(userId: userId)
        let unprocessed = sessions.filter { ($0.pleasureVector?.embedding ?? []).isEmpty }
        
        for var session in unprocessed {
            // Generate embedding from session data
            let vector = VectorService.shared.generateEmbedding(from: session)
            if session.pleasureVector == nil {
                session.pleasureVector = SessionPleasureVector()
            }
            session.pleasureVector?.embedding = vector
            
            try await firebase.updateSession(session)
        }
    }
    
    /// Generate weekly insights using Gemini
    private func generateWeeklyInsights() async throws {
        // Get sessions from the past week
        guard let userId = firebase.currentUser?.id else { return }
        
        let sessions = try await firebase.fetchSessions(userId: userId)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentSessions = sessions.filter { $0.timestampStart >= weekAgo }
        
        guard !recentSessions.isEmpty else { return }
        
        // Use InsightEngine to generate insights
        _ = try await InsightEngine.shared.generateWeeklyInsight(from: recentSessions)
    }
}

// MARK: - Queue Manager

/// Manages a queue of pending operations
actor PendingOperationsQueue {
    static let shared = PendingOperationsQueue()
    
    private var audioUploads: [URL] = []
    private var sessionUpdates: [String] = []
    
    func enqueueAudioUpload(_ url: URL) {
        audioUploads.append(url)
    }
    
    func enqueueSessionUpdate(_ sessionId: String) {
        sessionUpdates.append(sessionId)
    }
    
    func dequeuePendingAudio() -> [URL] {
        let pending = audioUploads
        audioUploads.removeAll()
        return pending
    }
    
    func dequeuePendingSessions() -> [String] {
        let pending = sessionUpdates
        sessionUpdates.removeAll()
        return pending
    }
}

