//
//  PlaceEditView.swift
//  atlas
//
//  Created by Scott Shawcroft on 6/25/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct PlaceEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let place: Place?
    let currentLocation: CLLocation?
    
    @State private var emoji: String = "❓"
    @State private var name: String = ""
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var showPolicy: ShowPolicy = .nearby
    @State private var nearbyDistance: Double = 0.1
    @State private var timeSlots: [TimeSlot] = []
    @State private var showingTimeSlotEditor = false
    
    private var isEditing: Bool {
        place != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("🏠", text: $emoji)
                            .multilineTextAlignment(.trailing)
                            .font(.title2)
                    }
                    
                    TextField("Name", text: $name)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        HStack {
                            Text("Lat:")
                            TextField("0.0", value: $latitude, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        HStack {
                            Text("Lon:")
                            TextField("0.0", value: $longitude, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        if isEditing && currentLocation != nil {
                            Button("Use Current Location") {
                                if let currentLocation = currentLocation {
                                    latitude = currentLocation.coordinate.latitude
                                    longitude = currentLocation.coordinate.longitude
                                }
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                
                Section("Visibility") {
                    Picker("Show Policy", selection: $showPolicy) {
                        ForEach(ShowPolicy.allCases, id: \.self) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    if showPolicy == .nearby {
                        HStack {
                            Text("Distance (miles)")
                            Spacer()
                            TextField("0.1", value: $nearbyDistance, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                        }
                    }
                    
                    if showPolicy == .atCertainTimes {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Time Slots")
                                    .font(.headline)
                                Spacer()
                                Button("Add") {
                                    showingTimeSlotEditor = true
                                }
                            }
                            
                            ForEach(timeSlots, id: \.id) { timeSlot in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(timeSlot.name)
                                        .font(.headline)
                                    HStack {
                                        Text(timeSlot.dayNames)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text(timeSlot.timeRange)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .onDelete(perform: deleteTimeSlots)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Place" : "New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlace()
                    }
                    .disabled(name.isEmpty || emoji.isEmpty)
                }
            }
            .sheet(isPresented: $showingTimeSlotEditor) {
                TimeSlotEditView { timeSlot in
                    timeSlots.append(timeSlot)
                }
            }
        }
        .onAppear {
            loadPlaceData()
        }
    }
    
    private func loadPlaceData() {
        if let place = place {
            emoji = place.emoji
            name = place.name
            latitude = place.latitude
            longitude = place.longitude
            showPolicy = place.showPolicy
            nearbyDistance = place.nearbyDistance
            timeSlots = place.timeSlots
        } else if let currentLocation = currentLocation {
            // Default new places to current location
            latitude = currentLocation.coordinate.latitude
            longitude = currentLocation.coordinate.longitude
        }
    }
    
    private func savePlace() {
        if let existingPlace = place {
            existingPlace.emoji = emoji
            existingPlace.name = name
            existingPlace.latitude = latitude
            existingPlace.longitude = longitude
            existingPlace.showPolicy = showPolicy
            existingPlace.nearbyDistance = nearbyDistance
            
            // Clear existing time slots and add new ones
            existingPlace.timeSlots.removeAll()
            for timeSlot in timeSlots {
                timeSlot.place = existingPlace
                existingPlace.timeSlots.append(timeSlot)
            }
        } else {
            let newPlace = Place(
                emoji: emoji,
                name: name,
                latitude: latitude,
                longitude: longitude,
                showPolicy: showPolicy,
                nearbyDistance: nearbyDistance
            )
            
            for timeSlot in timeSlots {
                timeSlot.place = newPlace
                newPlace.timeSlots.append(timeSlot)
            }
            
            modelContext.insert(newPlace)
        }
        
        dismiss()
    }
    
    private func deleteTimeSlots(offsets: IndexSet) {
        timeSlots.remove(atOffsets: offsets)
    }
}

struct TimeSlotEditView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onSave: (TimeSlot) -> Void
    
    @State private var name: String = ""
    @State private var selectedDays: Set<Int> = []
    @State private var startHour = 9
    @State private var startMinute = 0
    @State private var endHour = 17
    @State private var endMinute = 0
    
    private let dayNames = Calendar.current.weekdaySymbols
    private let hours = Array(0...23)
    private let minutes = Array(stride(from: 0, to: 60, by: 15))
    
    var body: some View {
        NavigationView {
            Form {
                Section("Name") {
                    TextField("Time slot name", text: $name)
                        .textInputAutocapitalization(.words)
                }
                
                Section("Days") {
                    ForEach(1...7, id: \.self) { day in
                        HStack {
                            Button(action: {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedDays.contains(day) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedDays.contains(day) ? .blue : .gray)
                                    Text(dayNames[day - 1])
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Quick select buttons
                    HStack {
                        Button("Weekdays") {
                            selectedDays = Set([2, 3, 4, 5, 6]) // Mon-Fri
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Weekends") {
                            selectedDays = Set([1, 7]) // Sun, Sat
                        }
                        .buttonStyle(.bordered)
                        
                        Button("All") {
                            selectedDays = Set(1...7)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear") {
                            selectedDays.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Section("Start Time") {
                    HStack {
                        Picker("Hour", selection: $startHour) {
                            ForEach(hours, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(maxWidth: .infinity)
                        
                        Text(":")
                        
                        Picker("Minute", selection: $startMinute) {
                            ForEach(minutes, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                }
                
                Section("End Time") {
                    HStack {
                        Picker("Hour", selection: $endHour) {
                            ForEach(hours, id: \.self) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(maxWidth: .infinity)
                        
                        Text(":")
                        
                        Picker("Minute", selection: $endMinute) {
                            ForEach(minutes, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Add Time Slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let timeSlot = TimeSlot(
                            name: name,
                            daysOfWeek: Array(selectedDays),
                            startHour: startHour,
                            startMinute: startMinute,
                            endHour: endHour,
                            endMinute: endMinute
                        )
                        onSave(timeSlot)
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedDays.isEmpty)
                }
            }
        }
    }
}

#Preview {
    PlaceEditView(place: nil, currentLocation: nil)
        .modelContainer(for: [Place.self, TimeSlot.self], inMemory: true)
}