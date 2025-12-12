// CircadianProfile.swift
// Maps time-of-day to preferred pleasure dimensions

import Foundation

struct CircadianProfile: Codable, Equatable {
    var dawn: [PleasureProfile.Dimension] = [.natureMirror, .mobility]
    var morning: [PleasureProfile.Dimension] = [.order, .path, .power]
    var afternoon: [PleasureProfile.Dimension] = [.materialPlay, .serendipityFollowing]
    var evening: [PleasureProfile.Dimension] = [.enclosure, .food, .repetition]
    var night: [PleasureProfile.Dimension] = [.ignorance, .horizon, .eroticUncertainty]
    
    enum TimeOfDay: String, CaseIterable, Codable {
        case dawn      // 5am - 7am
        case morning   // 7am - 12pm
        case afternoon // 12pm - 5pm
        case evening   // 5pm - 9pm
        case night     // 9pm - 5am
        
        static func current(from date: Date = Date()) -> TimeOfDay {
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 5..<7: return .dawn
            case 7..<12: return .morning
            case 12..<17: return .afternoon
            case 17..<21: return .evening
            default: return .night
            }
        }
    }
    
    func dimensions(for timeOfDay: TimeOfDay) -> [PleasureProfile.Dimension] {
        switch timeOfDay {
        case .dawn: return dawn
        case .morning: return morning
        case .afternoon: return afternoon
        case .evening: return evening
        case .night: return night
        }
    }
    
    func currentDimensions() -> [PleasureProfile.Dimension] {
        dimensions(for: .current())
    }
}
