// LogBookView.swift
// The Scribe: Session history, insights, and pleasure visualization

import SwiftUI
import Charts

struct LogBookView: View {
    @StateObject private var firebase = FirebaseManager.shared
    @StateObject private var insightEngine = InsightEngine.shared
    @StateObject private var vectorService = VectorService.shared
    
    @State private var sessions: [Session] = []
    @State private var selectedSession: Session?
    @State private var isLoading = true
    @State private var showPleasureSpace = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Latest Insight
                    if let insight = insightEngine.latestInsight {
                        insightCard(insight)
                    }
                    
                    // Quick Stats
                    statsRow
                    
                    // Pleasure Space Button
                    Button {
                        showPleasureSpace = true
                    } label: {
                        HStack {
                            Image(systemName: "chart.dots.scatter")
                            Text("Explore Pleasure Space")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    
                    // Session Timeline
                    sessionTimeline
                }
                .padding(.vertical)
            }
            .navigationTitle("Scribe")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await generateInsight()
                        }
                    } label: {
                        Image(systemName: insightEngine.isGenerating ? "brain" : "sparkles")
                    }
                    .disabled(insightEngine.isGenerating)
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
            .sheet(isPresented: $showPleasureSpace) {
                PleasureSpaceView(sessions: sessions)
            }
        }
        .task {
            await loadSessions()
        }
    }
    
    // MARK: - Insight Card
    
    private func insightCard(_ insight: Insight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: insightIcon(insight.type))
                    .foregroundStyle(.purple)
                Text(insight.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(insight.generatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(insight.summary)
                .font(.body)
            
            if !insight.dimensions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(insight.dimensions.prefix(4), id: \.self) { dim in
                        Text(dim.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 16) {
            statCard(value: "\(sessions.count)", label: "Sessions", icon: "leaf")
            statCard(value: uniqueDimensionsCount, label: "Dimensions", icon: "sparkles")
            statCard(value: totalDuration, label: "Total Time", icon: "clock")
        }
        .padding(.horizontal)
    }
    
    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Session Timeline
    
    private var sessionTimeline: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .font(.headline)
                .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "leaf")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(groupedSessions, id: \.key) { date, daySessions in
                        Section {
                            ForEach(daySessions) { session in
                                SessionCard(session: session)
                                    .onTapGesture {
                                        selectedSession = session
                                    }
                            }
                        } header: {
                            Text(date)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Helpers
    
    private var groupedSessions: [(key: String, value: [Session])] {
        let grouped = Dictionary(grouping: sessions) { session in
            session.timestampStart.formatted(date: .abbreviated, time: .omitted)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    private var uniqueDimensionsCount: String {
        let allDims = sessions.flatMap { $0.pleasureVector?.dominantDimensions ?? [] }
        return "\(Set(allDims).count)"
    }
    
    private var totalDuration: String {
        let totalMinutes = sessions.compactMap { session -> Int? in
            guard let end = session.timestampEnd else { return nil }
            return Int(end.timeIntervalSince(session.timestampStart) / 60)
        }.reduce(0, +)
        
        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        } else {
            return "\(totalMinutes / 60)h"
        }
    }
    
    private func insightIcon(_ type: InsightType) -> String {
        switch type {
        case .pattern: return "point.3.connected.trianglepath.dotted"
        case .weekly: return "calendar"
        case .suggestion: return "lightbulb"
        case .milestone: return "star.fill"
        }
    }
    
    private func loadSessions() async {
        guard let userId = firebase.currentUser?.id else {
            isLoading = false
            return
        }
        
        do {
            sessions = try await firebase.fetchSessions(userId: userId)
            isLoading = false
        } catch {
            print("Error loading sessions: \(error)")
            isLoading = false
        }
    }
    
    private func generateInsight() async {
        guard let userId = firebase.currentUser?.id else { return }
        
        do {
            _ = try await insightEngine.generateNextSessionSuggestion(userId: userId)
        } catch {
            print("Error generating insight: \(error)")
        }
    }
}

// MARK: - Session Card

struct SessionCard: View {
    let session: Session
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: stateIcon)
                    .foregroundStyle(stateColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.state.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(session.timestampStart.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let end = session.timestampEnd {
                    let duration = Int(end.timeIntervalSince(session.timestampStart) / 60)
                    Text("\(duration) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Dimension badges
            let dims = session.pleasureVector?.dominantDimensions ?? []
            if !dims.isEmpty {
                HStack(spacing: 6) {
                    ForEach(dims.prefix(4), id: \.self) { dim in
                        Text(dim.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(stateColor.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    if dims.count > 4 {
                        Text("+\(dims.count - 4)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var stateIcon: String {
        switch session.state {
        case .idle: return "pause.circle"
        case .drift: return "wind"
        case .mastery: return "target"
        case .socialSync: return "person.2"
        case .reflection: return "sparkles"
        }
    }
    
    private var stateColor: Color {
        switch session.state {
        case .idle: return .gray
        case .drift: return .purple
        case .mastery: return .orange
        case .socialSync: return .green
        case .reflection: return .indigo
        }
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    let session: Session
    @StateObject private var insightEngine = InsightEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: stateIcon)
                            .font(.largeTitle)
                            .foregroundStyle(stateColor)
                        
                        Text(session.state.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(session.timestampStart.formatted(date: .long, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    
                    // Duration
                    if let end = session.timestampEnd {
                        HStack {
                            Image(systemName: "clock")
                            let duration = Int(end.timeIntervalSince(session.timestampStart) / 60)
                            Text("\(duration) minutes")
                        }
                        .foregroundStyle(.secondary)
                    }
                    
                    // State History
                    if session.stateHistory.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("State Flow")
                                .font(.headline)
                            
                            HStack(spacing: 8) {
                                ForEach(session.stateHistory, id: \.self) { state in
                                    Image(systemName: iconFor(state))
                                        .foregroundStyle(colorFor(state))
                                }
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                Image(systemName: stateIcon)
                                    .foregroundStyle(stateColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                    
                    // Pleasure Dimensions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Activated Dimensions")
                            .font(.headline)
                        
                        let dims = session.pleasureVector?.activatedDimensions ?? [:]
                        if dims.isEmpty {
                            Text("No dimensions recorded")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(Array(dims.keys.sorted(by: { dims[$0]! > dims[$1]! })), id: \.self) { dim in
                                HStack {
                                    Text(dim.displayName)
                                    Spacer()
                                    ProgressView(value: dims[dim] ?? 0)
                                        .frame(width: 100)
                                    Text(String(format: "%.0f%%", (dims[dim] ?? 0) * 100))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    // Notes
                    if let notes = session.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            Text(notes)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                    
                    // Generate Insight Button
                    Button {
                        Task {
                            try? await insightEngine.generateSessionInsight(for: session)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Generate Insight")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .padding(.horizontal)
                    .disabled(insightEngine.isGenerating)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var stateIcon: String {
        iconFor(session.state)
    }
    
    private var stateColor: Color {
        colorFor(session.state)
    }
    
    private func iconFor(_ state: SessionState) -> String {
        switch state {
        case .idle: return "pause.circle"
        case .drift: return "wind"
        case .mastery: return "target"
        case .socialSync: return "person.2"
        case .reflection: return "sparkles"
        }
    }
    
    private func colorFor(_ state: SessionState) -> Color {
        switch state {
        case .idle: return .gray
        case .drift: return .purple
        case .mastery: return .orange
        case .socialSync: return .green
        case .reflection: return .indigo
        }
    }
}

#Preview {
    LogBookView()
}
