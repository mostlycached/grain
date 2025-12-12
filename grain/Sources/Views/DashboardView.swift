// DashboardView.swift
// The Architect: Main dashboard showing user state and suggested missions

import SwiftUI
import CoreLocation

struct DashboardView: View {
    @EnvironmentObject var stateMachine: SessionStateMachine
    @StateObject private var firebase = FirebaseManager.shared
    @StateObject private var inventory = InventoryService.shared
    @StateObject private var planner = PlannerService.shared
    @StateObject private var calendar = CalendarManager.shared
    @StateObject private var locationManager = LocationManager()
    
    @State private var selectedDuration: MissionDuration = .medium
    @State private var showScheduler = false
    @State private var scheduleDate = Date()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Current State Card
                    currentStateCard
                    
                    // Circadian Context
                    circadianCard
                    
                    // Mission Section
                    missionSection
                    
                    // Recommended Inventory
                    recommendedInventorySection
                    
                    // Today's Schedule
                    if !calendar.todaysMissions().isEmpty {
                        todaysScheduleSection
                    }
                }
                .padding()
            }
            .navigationTitle("Architect")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        InventoryMapView()
                    } label: {
                        Image(systemName: "map")
                    }
                }
            }
            .sheet(isPresented: $showScheduler) {
                scheduleSheet
            }
        }
        .task {
            await inventory.fetchAll()
            calendar.fetchScheduledMissions()
        }
    }
    
    // MARK: - Current State Card
    
    private var currentStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current State")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Menu {
                    ForEach(GrainUser.UserState.allCases, id: \.self) { state in
                        Button(state.rawValue.capitalized) {
                            updateUserState(state)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down.circle")
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Circle()
                    .fill(stateColor)
                    .frame(width: 12, height: 12)
                
                Text(firebase.currentUser?.currentState.rawValue.capitalized ?? "Unknown")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            if let user = firebase.currentUser {
                let suggested = user.currentState.suggestedDimensions
                HStack(spacing: 6) {
                    ForEach(suggested.prefix(3), id: \.self) { dim in
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Circadian Card
    
    private var circadianCard: some View {
        let timeOfDay = CircadianProfile.TimeOfDay.current()
        let dimensions = firebase.currentUser?.circadianProfile.dimensions(for: timeOfDay) ?? []
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: timeOfDayIcon(timeOfDay))
                    .foregroundStyle(.orange)
                Text(timeOfDay.rawValue.capitalized)
                    .font(.headline)
                
                Spacer()
                
                Text(Date().formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 8) {
                ForEach(dimensions, id: \.self) { dim in
                    Text(dim.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Mission Section
    
    private var missionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Mission")
                    .font(.headline)
                
                Spacer()
                
                Picker("Duration", selection: $selectedDuration) {
                    ForEach(MissionDuration.allCases, id: \.self) { duration in
                        Text(duration.rawValue).tag(duration)
                    }
                }
                .pickerStyle(.menu)
            }
            
            if let mission = planner.currentMission {
                missionCard(mission)
            } else {
                generateMissionButton
            }
        }
    }
    
    private func missionCard(_ mission: Mission) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(mission.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    planner.currentMission = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(mission.description)
                .font(.body)
                .foregroundStyle(.secondary)
            
            // Dimensions
            HStack(spacing: 6) {
                ForEach(mission.dimensions, id: \.self) { dim in
                    Text(dim.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            
            // Steps
            if !mission.steps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(mission.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(step)
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            HStack {
                Label(mission.duration, systemImage: "clock")
                Spacer()
                Label(mission.location, systemImage: "mappin")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button {
                    showScheduler = true
                } label: {
                    Label("Schedule", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button {
                    startMissionNow(mission)
                } label: {
                    Label("Start Now", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var generateMissionButton: some View {
        Button {
            Task {
                await generateMission()
            }
        } label: {
            HStack {
                if planner.isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text("Generate Mission")
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
        .disabled(planner.isGenerating)
    }
    
    // MARK: - Recommended Inventory
    
    private var recommendedInventorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recommended for You")
                    .font(.headline)
                Spacer()
                NavigationLink("See All") {
                    InventoryMapView()
                }
                .font(.caption)
            }
            
            let recommended = firebase.currentUser.map { inventory.recommendedItems(for: $0) } ?? []
            
            if recommended.isEmpty {
                Text("Update your state to get recommendations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recommended.prefix(5)) { item in
                            InventoryCard(item: item)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Today's Schedule
    
    private var todaysScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Missions")
                .font(.headline)
            
            ForEach(calendar.todaysMissions()) { scheduled in
                HStack {
                    VStack(alignment: .leading) {
                        Text(scheduled.mission.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(scheduled.scheduledDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        try? calendar.removeMission(scheduled)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    // MARK: - Schedule Sheet
    
    private var scheduleSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let mission = planner.currentMission {
                    Text(mission.title)
                        .font(.headline)
                    
                    DatePicker(
                        "When",
                        selection: $scheduleDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    
                    Button {
                        Task {
                            try? await calendar.scheduleMission(mission, at: scheduleDate)
                            showScheduler = false
                        }
                    } label: {
                        Text("Add to Calendar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }
            .padding()
            .navigationTitle("Schedule Mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showScheduler = false
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var stateColor: Color {
        switch firebase.currentUser?.currentState {
        case .depleted: return .red
        case .anxious: return .orange
        case .scattered: return .yellow
        case .neutral: return .gray
        case .curious: return .blue
        case .energized: return .green
        case .flowing: return .purple
        case .none: return .gray
        }
    }
    
    private func timeOfDayIcon(_ time: CircadianProfile.TimeOfDay) -> String {
        switch time {
        case .dawn: return "sunrise"
        case .morning: return "sun.max"
        case .afternoon: return "sun.haze"
        case .evening: return "sunset"
        case .night: return "moon.stars"
        }
    }
    
    private func generateMission() async {
        guard let user = firebase.currentUser else { return }
        
        do {
            _ = try await planner.generateMission(
                for: user,
                duration: selectedDuration
            )
        } catch {
            print("Error generating mission: \(error)")
        }
    }
    
    private func updateUserState(_ state: GrainUser.UserState) {
        guard var user = firebase.currentUser else { return }
        user.currentState = state
        Task {
            try? await firebase.updateUser(user)
        }
    }
    
    private func startMissionNow(_ mission: Mission) {
        // Transition to Guide and start session
        Task {
            try? await stateMachine.startSession(
                userId: firebase.currentUser?.id ?? "anonymous"
            )
            // Activate mission dimensions
            for dim in mission.dimensions {
                stateMachine.activateDimension(dim)
            }
        }
    }
}

// MARK: - Inventory Card

struct InventoryCard: View {
    let item: InventoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: itemIcon)
                .font(.title2)
                .foregroundStyle(.purple)
            
            Text(item.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Text(item.type.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var itemIcon: String {
        switch item.type {
        case .tool: return "wrench.and.screwdriver"
        case .space: return "building.2"
        case .expert: return "person.fill"
        }
    }
}

// MARK: - Location Manager

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    private let manager = CLLocationManager()
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.location = locations.first
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }
}

