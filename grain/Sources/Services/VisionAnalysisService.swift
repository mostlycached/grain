// VisionAnalysisService.swift
// Camera capture and Gemini vision analysis

import Foundation
import AVFoundation
import UIKit

@MainActor
final class VisionAnalysisService: NSObject, ObservableObject {
    static let shared = VisionAnalysisService()
    
    @Published var isCapturing = false
    @Published var isAnalyzing = false
    @Published var lastAnalysis: VisionAnalysis?
    @Published var error: Error?
    
    private let gemini = GeminiService.shared
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var photoContinuation: CheckedContinuation<Data, Error>?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Camera Setup
    
    func setupCamera() async throws {
        guard await requestCameraPermission() else {
            throw VisionError.permissionDenied
        }
        
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            throw VisionError.cameraUnavailable
        }
        
        photoOutput = AVCapturePhotoOutput()
        
        guard let captureSession = captureSession,
              let photoOutput = photoOutput,
              captureSession.canAddInput(input),
              captureSession.canAddOutput(photoOutput) else {
            throw VisionError.setupFailed
        }
        
        captureSession.addInput(input)
        captureSession.addOutput(photoOutput)
    }
    
    func startSession() {
        guard let session = captureSession else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    func stopSession() {
        captureSession?.stopRunning()
    }
    
    // MARK: - Photo Capture
    
    /// Capture photo and return compressed JPEG data
    func capturePhoto() async throws -> Data {
        guard let photoOutput = photoOutput else {
            throw VisionError.notSetup
        }
        
        isCapturing = true
        defer { isCapturing = false }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        
        return try await withCheckedThrowingContinuation { continuation in
            self.photoContinuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    /// Capture and analyze with Gemini
    func captureAndAnalyze(prompt: String? = nil) async throws -> VisionAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let photoData = try await capturePhoto()
        let compressedData = compressImage(photoData, maxSizeKB: 500)
        
        let analysisText = try await gemini.analyzeImage(
            compressedData,
            prompt: prompt ?? GeminiService.visionAnalysisPrompt
        )
        
        let dimensions = extractDimensions(from: analysisText)
        
        let analysis = VisionAnalysis(
            text: analysisText,
            detectedDimensions: dimensions,
            imageData: compressedData,
            timestamp: Date()
        )
        
        lastAnalysis = analysis
        return analysis
    }
    
    /// Analyze an existing image
    func analyzeImage(_ imageData: Data, prompt: String? = nil) async throws -> VisionAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let compressedData = compressImage(imageData, maxSizeKB: 500)
        
        let analysisText = try await gemini.analyzeImage(
            compressedData,
            prompt: prompt ?? GeminiService.visionAnalysisPrompt
        )
        
        let dimensions = extractDimensions(from: analysisText)
        
        let analysis = VisionAnalysis(
            text: analysisText,
            detectedDimensions: dimensions,
            imageData: compressedData,
            timestamp: Date()
        )
        
        lastAnalysis = analysis
        return analysis
    }
    
    // MARK: - Helpers
    
    private func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
    
    private func compressImage(_ data: Data, maxSizeKB: Int) -> Data {
        guard let image = UIImage(data: data) else { return data }
        
        var compression: CGFloat = 0.8
        var compressedData = image.jpegData(compressionQuality: compression) ?? data
        
        while compressedData.count > maxSizeKB * 1024 && compression > 0.1 {
            compression -= 0.1
            compressedData = image.jpegData(compressionQuality: compression) ?? compressedData
        }
        
        return compressedData
    }
    
    private func extractDimensions(from text: String) -> [PleasureProfile.Dimension] {
        let lowerText = text.lowercased()
        return PleasureProfile.Dimension.allCases.filter { dim in
            lowerText.contains(dim.rawValue.lowercased()) ||
            lowerText.contains(dim.displayName.lowercased())
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension VisionAnalysisService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        // Extract data on the callback thread before crossing actor boundary
        let photoData = photo.fileDataRepresentation()
        let captureError = error
        
        Task { @MainActor in
            if let error = captureError {
                photoContinuation?.resume(throwing: error)
            } else if let data = photoData {
                photoContinuation?.resume(returning: data)
            } else {
                photoContinuation?.resume(throwing: VisionError.captureFailed)
            }
            photoContinuation = nil
        }
    }
}

// MARK: - Types

struct VisionAnalysis: Identifiable {
    let id = UUID()
    let text: String
    let detectedDimensions: [PleasureProfile.Dimension]
    let imageData: Data
    let timestamp: Date
}

enum VisionError: Error, LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case setupFailed
    case notSetup
    case captureFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Camera permission denied"
        case .cameraUnavailable: return "Camera not available"
        case .setupFailed: return "Failed to setup camera"
        case .notSetup: return "Camera not setup"
        case .captureFailed: return "Failed to capture photo"
        }
    }
}
