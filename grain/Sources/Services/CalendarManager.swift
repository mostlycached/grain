// CalendarManager.swift
// EventKit integration for scheduling missions

import Foundation
import EventKit

@MainActor
final class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    
    @Published var hasCalendarAccess = false
    @Published var scheduledMissions: [ScheduledMission] = []
    
    private let eventStore = EKEventStore()
    private let calendarTitle = "grain Missions"
    
    private init() {
        checkAccess()
    }
    
    // MARK: - Authorization
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            hasCalendarAccess = granted
            return granted
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }
    
    private func checkAccess() {
        let status = EKEventStore.authorizationStatus(for: .event)
        hasCalendarAccess = status == .fullAccess
    }
    
    // MARK: - Calendar Management
    
    /// Get or create the grain calendar
    private func getOrCreateCalendar() -> EKCalendar? {
        // Check if grain calendar exists
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarTitle }) {
            return existing
        }
        
        // Create new calendar
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle
        calendar.cgColor = CGColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0) // Purple
        
        // Find a source (prefer iCloud, fallback to local)
        if let iCloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV }) {
            calendar.source = iCloudSource
        } else if let localSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
            calendar.source = localSource
        } else {
            calendar.source = eventStore.defaultCalendarForNewEvents?.source
        }
        
        do {
            try eventStore.saveCalendar(calendar, commit: true)
            return calendar
        } catch {
            print("Error creating calendar: \(error)")
            return eventStore.defaultCalendarForNewEvents
        }
    }
    
    // MARK: - Mission Scheduling
    
    /// Schedule a mission as a calendar event
    func scheduleMission(_ mission: Mission, at date: Date) async throws -> ScheduledMission {
        guard hasCalendarAccess else {
            let granted = await requestAccess()
            if !granted {
                throw CalendarError.accessDenied
            }
            return try await scheduleMission(mission, at: date)
        }
        
        guard let calendar = getOrCreateCalendar() else {
            throw CalendarError.calendarNotFound
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "🌾 \(mission.title)"
        event.notes = formatMissionNotes(mission)
        event.startDate = date
        event.endDate = date.addingTimeInterval(parseDuration(mission.duration))
        event.calendar = calendar
        event.location = mission.location
        
        // Add alert 15 minutes before
        event.addAlarm(EKAlarm(relativeOffset: -15 * 60))
        
        try eventStore.save(event, span: .thisEvent)
        
        let scheduled = ScheduledMission(
            mission: mission,
            eventIdentifier: event.eventIdentifier,
            scheduledDate: date
        )
        
        scheduledMissions.append(scheduled)
        return scheduled
    }
    
    /// Remove a scheduled mission
    func removeMission(_ scheduled: ScheduledMission) throws {
        guard let event = eventStore.event(withIdentifier: scheduled.eventIdentifier) else {
            return
        }
        
        try eventStore.remove(event, span: .thisEvent)
        scheduledMissions.removeAll { $0.eventIdentifier == scheduled.eventIdentifier }
    }
    
    /// Get today's scheduled missions
    func todaysMissions() -> [ScheduledMission] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return scheduledMissions.filter { mission in
            mission.scheduledDate >= startOfDay && mission.scheduledDate < endOfDay
        }
    }
    
    /// Fetch all grain events from calendar
    func fetchScheduledMissions() {
        guard hasCalendarAccess, let calendar = getOrCreateCalendar() else { return }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: [calendar]
        )
        
        let events = eventStore.events(matching: predicate)
        
        // Note: We can't fully reconstruct Mission objects from events
        // This is a simplified version
        scheduledMissions = events.compactMap { event in
            guard let identifier = event.eventIdentifier else { return nil }
            
            return ScheduledMission(
                mission: Mission(
                    title: event.title?.replacingOccurrences(of: "🌾 ", with: "") ?? "Mission",
                    description: event.notes ?? "",
                    duration: formatDuration(event.endDate.timeIntervalSince(event.startDate)),
                    location: event.location ?? "",
                    dimensions: []
                ),
                eventIdentifier: identifier,
                scheduledDate: event.startDate
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private func formatMissionNotes(_ mission: Mission) -> String {
        var notes = mission.description + "\n\n"
        
        if !mission.dimensions.isEmpty {
            notes += "Pleasure Dimensions: \(mission.dimensions.map(\.displayName).joined(separator: ", "))\n\n"
        }
        
        if !mission.steps.isEmpty {
            notes += "Steps:\n"
            for (index, step) in mission.steps.enumerated() {
                notes += "\(index + 1). \(step)\n"
            }
        }
        
        notes += "\n— Generated by grain"
        return notes
    }
    
    private func parseDuration(_ duration: String) -> TimeInterval {
        if duration.contains("15") { return 15 * 60 }
        if duration.contains("30") { return 30 * 60 }
        if duration.contains("1 hour") || duration.contains("60") { return 60 * 60 }
        if duration.contains("2") { return 120 * 60 }
        return 30 * 60 // Default 30 minutes
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes) mins"
        } else {
            let hours = minutes / 60
            let remaining = minutes % 60
            if remaining == 0 {
                return "\(hours) hour\(hours > 1 ? "s" : "")"
            } else {
                return "\(hours)h \(remaining)m"
            }
        }
    }
}

// MARK: - Supporting Types

struct ScheduledMission: Identifiable {
    var id: String { eventIdentifier }
    let mission: Mission
    let eventIdentifier: String
    let scheduledDate: Date
}

enum CalendarError: Error, LocalizedError {
    case accessDenied
    case calendarNotFound
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Calendar access denied"
        case .calendarNotFound: return "Could not find or create calendar"
        case .saveFailed: return "Failed to save event"
        }
    }
}
