//
//  PlacesListView.swift
//  atlas
//
//  Created by Scott Shawcroft on 6/25/25.
//

import SwiftUI
import SwiftData
import CoreLocation

struct PlacesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var places: [Place]
    @State private var showingAddPlace = false
    
    let currentLocation: CLLocation?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(places, id: \.id) { place in
                    NavigationLink(destination: PlaceEditView(place: place, currentLocation: currentLocation)) {
                        PlaceRowView(place: place)
                    }
                }
                .onDelete(perform: deletePlaces)
            }
            .navigationTitle("Places")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddPlace = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPlace) {
                PlaceEditView(place: nil, currentLocation: currentLocation)
            }
            .onAppear {
                createDefaultPlacesIfNeeded()
            }
        }
    }
    
    private func deletePlaces(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(places[index])
            }
        }
    }
    
    private func createDefaultPlacesIfNeeded() {
        if places.isEmpty {
            let home = Place(emoji: "🏠", name: "Home", latitude: 0.0, longitude: 0.0, showPolicy: .always)
            let work = Place(emoji: "💼", name: "Work", latitude: 0.0, longitude: 0.0, showPolicy: .always)
            let daycare = Place(emoji: "👶", name: "Daycare", latitude: 47.669553, longitude: -122.363616, showPolicy: .nearby, nearbyDistance: 0.1)
            
            modelContext.insert(home)
            modelContext.insert(work)
            modelContext.insert(daycare)
        }
    }
}

struct PlaceRowView: View {
    let place: Place
    
    var body: some View {
        HStack {
            Text(place.emoji)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.headline)
                
                HStack {
                    Text(place.showPolicy.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if place.showPolicy == .nearby {
                        Text("(\(place.nearbyDistance, specifier: "%.1f") mi)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.6f", place.latitude))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(String(format: "%.6f", place.longitude))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PlacesListView(currentLocation: nil)
        .modelContainer(for: [Place.self, TimeSlot.self], inMemory: true)
}