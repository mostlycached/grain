// LiveSessionManager.swift
// Audio recording and Cloud Function communication for live coaching

import Foundation
import AVFoundation
import Speech

@MainActor
final class LiveSessionManager: NSObject, ObservableObject {
    static let shared = LiveSessionManager()
    
    // MARK: - Published State
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var audioLevel: Float = 0
    @Published var lastResponse: LiveResponse?
    @Published var transcript: String = ""
    @Published var error: Error?
    
    // MARK: - Audio Components
    private var audioEngine: AVAudioEngine?
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    // Session tracking
    private var sessionId: String?
    private let gemini = GeminiService.shared
    
    private override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            self.error = error
            print("Audio session setup error: \(error)")
        }
    }
    
    // MARK: - Recording Control
    
    func startSession(sessionId: String) {
        self.sessionId = sessionId
        gemini.connect()
    }
    
    func endSession() {
        stopRecording()
        sessionId = nil
        gemini.disconnect()
        transcript = ""
    }
    
    /// Start recording audio
    func startRecording() async throws {
        guard !isRecording else { return }
        
        // Request permissions
        guard await requestPermissions() else {
            throw LiveSessionError.permissionDenied
        }
        
        // Setup audio engine for level metering and speech recognition
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Create temp file for recording
        recordingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        
        guard let url = recordingURL else { return }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()
        
        // Setup speech recognition for live transcription
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcript = result.bestTranscription.formattedString
                }
            }
        }
        
        // Install tap for audio level and speech recognition
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate audio level
            let level = self?.calculateLevel(buffer: buffer) ?? 0
            Task { @MainActor in
                self?.audioLevel = level
            }
        }
        
        try audioEngine.start()
        isRecording = true
    }
    
    /// Stop recording and process audio
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioRecorder?.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        isRecording = false
        audioLevel = 0
    }
    
    /// Stop and send to Gemini for processing
    func stopAndProcess() async throws {
        stopRecording()
        
        guard let url = recordingURL,
              let sessionId = sessionId else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        do {
            let audioData = try Data(contentsOf: url)
            let response = try await gemini.sendVoiceMessage(audioData, sessionId: sessionId)
            lastResponse = response
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: url)
        } catch {
            self.error = error
            throw error
        }
    }
    
    // MARK: - Push-to-Talk Flow
    
    /// Convenience method for push-to-talk: records while called, processes on release
    func pushToTalkStart() async {
        do {
            try await startRecording()
        } catch {
            self.error = error
        }
    }
    
    func pushToTalkEnd() async {
        do {
            try await stopAndProcess()
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Helpers
    
    private func requestPermissions() async -> Bool {
        // Microphone permission
        let audioStatus = await AVAudioApplication.requestRecordPermission()
        guard audioStatus else { return false }
        
        // Speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        return speechStatus
    }
    
    private func calculateLevel(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameLength)
        return min(average * 10, 1.0) // Normalize to 0-1
    }
}

// MARK: - Errors

enum LiveSessionError: Error, LocalizedError {
    case permissionDenied
    case recordingFailed
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone or speech permission denied"
        case .recordingFailed: return "Failed to record audio"
        case .processingFailed: return "Failed to process audio"
        }
    }
}
