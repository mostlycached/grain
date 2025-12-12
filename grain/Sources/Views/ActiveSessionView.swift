// ActiveSessionView.swift
// The Guide: Real-time somatic coaching view

import SwiftUI
import AVFoundation

struct ActiveSessionView: View {
    @EnvironmentObject var stateMachine: SessionStateMachine
    @StateObject private var liveSession = LiveSessionManager.shared
    @StateObject private var vision = VisionAnalysisService.shared
    @StateObject private var geofence = GeofenceManager.shared
    
    @State private var showCamera = false
    @State private var showNearby = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient based on state
                stateGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // State indicator
                    stateHeader
                    
                    Spacer()
                    
                    // Main content area
                    if stateMachine.currentState == .idle {
                        startSessionPrompt
                    } else {
                        sessionContent
                    }
                    
                    Spacer()
                    
                    // Control bar
                    if stateMachine.currentState != .idle {
                        controlBar
                    }
                }
            }
            .navigationTitle("Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !geofence.nearbyItems.isEmpty {
                        Button {
                            showNearby = true
                        } label: {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraAnalysisView()
            }
            .sheet(isPresented: $showNearby) {
                NearbyItemsSheet(items: geofence.nearbyItems)
            }
        }
    }
    
    // MARK: - State Header
    
    private var stateHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(stateColor)
                    .frame(width: 12, height: 12)
                
                Text(stateMachine.currentState.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            
            // Active dimensions
            if !stateMachine.activePleasureDimensions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(stateMachine.activePleasureDimensions), id: \.self) { dim in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(.white.opacity(0.5))
                                    .frame(width: 6, height: 6)
                                Text(dim.displayName)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top)
    }
    
    // MARK: - Start Session Prompt
    
    private var startSessionPrompt: some View {
        VStack(spacing: 24) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.6))
            
            Text("Ready to begin?")
                .font(.title2)
                .foregroundStyle(.white)
            
            Text("Start a session to activate somatic coaching")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
            
            Button {
                Task {
                    try? await stateMachine.startSession(
                        userId: FirebaseManager.shared.currentUser?.id ?? "anonymous"
                    )
                    liveSession.startSession(sessionId: stateMachine.currentSession?.id ?? "")
                }
            } label: {
                Label("Begin Drift", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.3))
        }
        .padding()
    }
    
    // MARK: - Session Content
    
    private var sessionContent: some View {
        VStack(spacing: 24) {
            // Waveform / Audio Level
            WaveformView(level: liveSession.audioLevel, isActive: liveSession.isRecording)
                .frame(height: 100)
                .padding(.horizontal)
            
            // Current transcript or response
            if !liveSession.transcript.isEmpty && liveSession.isRecording {
                Text(liveSession.transcript)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
            }
            
            if let response = liveSession.lastResponse {
                VStack(alignment: .leading, spacing: 8) {
                    if let text = response.text {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(.white)
                    }
                    
                    if !response.detectedDimensions.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(response.detectedDimensions, id: \.self) { dim in
                                Text(dim)
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.purple.opacity(0.3))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
            
            // Vision analysis result
            if let analysis = vision.lastAnalysis {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "eye")
                            .foregroundStyle(.cyan)
                        Text("Vision")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    
                    Text(analysis.text)
                        .font(.body)
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        ForEach(analysis.detectedDimensions, id: \.self) { dim in
                            Text(dim.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.cyan.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Control Bar
    
    private var controlBar: some View {
        VStack(spacing: 16) {
            // State transition buttons
            HStack(spacing: 16) {
                ForEach([SessionState.drift, .mastery, .socialSync], id: \.self) { state in
                    Button {
                        try? stateMachine.transition(to: state)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: stateIcon(state))
                                .font(.title2)
                            Text(state.rawValue.replacingOccurrences(of: "_", with: " "))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .foregroundStyle(stateMachine.currentState == state ? .white : .white.opacity(0.5))
                    .background(stateMachine.currentState == state ? .white.opacity(0.2) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            
            // Main controls
            HStack(spacing: 24) {
                // Camera button
                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.2))
                        .clipShape(Circle())
                }
                
                // Push-to-talk button
                Button {
                    // Handled by gesture
                } label: {
                    ZStack {
                        Circle()
                            .fill(liveSession.isRecording ? .red : .white)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: liveSession.isRecording ? "waveform" : "mic.fill")
                            .font(.title)
                            .foregroundStyle(liveSession.isRecording ? .white : .black)
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !liveSession.isRecording {
                                Task { await liveSession.pushToTalkStart() }
                            }
                        }
                        .onEnded { _ in
                            Task { await liveSession.pushToTalkEnd() }
                        }
                )
                
                // End session button
                Button {
                    Task {
                        liveSession.endSession()
                        try? await stateMachine.endSession()
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .frame(width: 56, height: 56)
                        .background(.red.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            .foregroundStyle(.white)
            .padding(.bottom, 16)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Helpers
    
    private var stateGradient: LinearGradient {
        let colors: [Color]
        switch stateMachine.currentState {
        case .idle:
            colors = [.gray.opacity(0.8), .gray.opacity(0.4)]
        case .drift:
            colors = [.purple.opacity(0.8), .blue.opacity(0.6)]
        case .mastery:
            colors = [.orange.opacity(0.8), .red.opacity(0.6)]
        case .socialSync:
            colors = [.green.opacity(0.8), .teal.opacity(0.6)]
        case .reflection:
            colors = [.indigo.opacity(0.8), .purple.opacity(0.6)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var stateColor: Color {
        switch stateMachine.currentState {
        case .idle: return .gray
        case .drift: return .purple
        case .mastery: return .orange
        case .socialSync: return .green
        case .reflection: return .indigo
        }
    }
    
    private func stateIcon(_ state: SessionState) -> String {
        switch state {
        case .idle: return "pause.circle"
        case .drift: return "wind"
        case .mastery: return "target"
        case .socialSync: return "person.2"
        case .reflection: return "sparkles"
        }
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let level: Float
    let isActive: Bool
    
    @State private var phase: Double = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let midY = size.height / 2
                let amplitude = CGFloat(level) * size.height * 0.4
                
                var path = Path()
                path.move(to: CGPoint(x: 0, y: midY))
                
                for x in stride(from: 0, to: size.width, by: 2) {
                    let relativeX = x / size.width
                    let sine = sin((relativeX * 4 * Double.pi) + phase)
                    let y = midY + (sine * amplitude)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                context.stroke(path, with: .color(.white.opacity(isActive ? 0.8 : 0.3)), lineWidth: 2)
            }
        }
        .onChange(of: level) {
            phase += 0.1
        }
    }
}

// MARK: - Camera Analysis View

struct CameraAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vision = VisionAnalysisService.shared
    @StateObject private var stateMachine = SessionStateMachine.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    // Camera preview would go here
                    // Using CameraPreviewView with AVCaptureSession
                    
                    Spacer()
                    
                    if let analysis = vision.lastAnalysis {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(analysis.text)
                                .font(.body)
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 6) {
                                ForEach(analysis.detectedDimensions, id: \.self) { dim in
                                    Button {
                                        stateMachine.activateDimension(dim)
                                    } label: {
                                        Text(dim.displayName)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(.purple.opacity(0.3))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                    }
                    
                    // Capture button
                    Button {
                        Task {
                            try? await vision.captureAndAnalyze()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            
                            Circle()
                                .fill(.white)
                                .frame(width: 60, height: 60)
                        }
                    }
                    .disabled(vision.isAnalyzing)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Analyze")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                try? await vision.setupCamera()
                vision.startSession()
            }
            .onDisappear {
                vision.stopSession()
            }
        }
    }
}

// MARK: - Nearby Items Sheet

struct NearbyItemsSheet: View {
    let items: [InventoryItem]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(items) { item in
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.headline)
                        Text(item.type.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Nearby")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ActiveSessionView()
        .environmentObject(SessionStateMachine())
}
