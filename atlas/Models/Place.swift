//
//  Place.swift
//  atlas
//
//  Created by Scott Shawcroft on 6/25/25.
//

import Foundation
import SwiftData

@Model
class Place {
    var id: UUID
    var emoji: String
    var name: String
    var latitude: Double
    var longitude: Double
    var showPolicy: ShowPolicy
    var nearbyDistance: Double // in miles
    var timeSlots: [TimeSlot]
    var createdAt: Date
    
    init(emoji: String, name: String, latitude: Double, longitude: Double, showPolicy: ShowPolicy = .nearby, nearbyDistance: Double = 0.1) {
        self.id = UUID()
        self.emoji = emoji
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.showPolicy = showPolicy
        self.nearbyDistance = nearbyDistance
        self.timeSlots = []
        self.createdAt = Date()
    }
}

enum ShowPolicy: String, CaseIterable, Codable {
    case always = "Always"
    case never = "Never"
    case nearby = "Nearby"
    case atCertainTimes = "At Certain Times"
    
    var displayName: String {
        return self.rawValue
    }
}

@Model
class TimeSlot {
    var id: UUID
    var name: String
    var daysOfWeek: [Int] // Array of days: 1 = Sunday, 2 = Monday, etc.
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var place: Place?
    
    init(name: String, daysOfWeek: [Int], startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.id = UUID()
        self.name = name
        self.daysOfWeek = daysOfWeek.sorted()
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }
    
    var dayNames: String {
        let calendar = Calendar.current
        let dayNames = calendar.weekdaySymbols
        let selectedDayNames = daysOfWeek.map { dayNames[$0 - 1] }
        
        if selectedDayNames.count == 7 {
            return "Every day"
        } else if selectedDayNames.count == 5 && daysOfWeek.contains(2) && daysOfWeek.contains(6) {
            // Check if it's weekdays (Mon-Fri)
            let weekdays = [2, 3, 4, 5, 6] // Mon-Fri
            if Set(daysOfWeek) == Set(weekdays) {
                return "Weekdays"
            }
        } else if selectedDayNames.count == 2 && daysOfWeek.contains(1) && daysOfWeek.contains(7) {
            // Check if it's weekend (Sat-Sun)
            let weekend = [1, 7] // Sun, Sat
            if Set(daysOfWeek) == Set(weekend) {
                return "Weekends"
            }
        }
        
        return selectedDayNames.joined(separator: ", ")
    }
    
    var timeRange: String {
        let startTime = String(format: "%02d:%02d", startHour, startMinute)
        let endTime = String(format: "%02d:%02d", endHour, endMinute)
        return "\(startTime) - \(endTime)"
    }
    
    var displayText: String {
        return "\(name): \(dayNames) \(timeRange)"
    }
}