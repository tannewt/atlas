//
//  ContentView.swift
//  atlas
//
//  Created by Scott Shawcroft on 6/9/25.
//

import SwiftUI
import Valhalla
import ValhallaModels
import ValhallaConfigModels
import CoreLocation
import UIKit
import AtlasLibrary

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var recentLocations: [CLLocation] = []
    
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
        
        requestLocationPermission()
    }
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        locationManager.startUpdatingLocation()
    }
    
    var onLocationUpdate: ((CLLocation) -> Void)?
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let newLocation = locations.last {
            location = newLocation
            
            // Keep track of last 15 locations
            recentLocations.append(newLocation)
            if recentLocations.count > 15 {
                recentLocations.removeFirst()
            }
            
            onLocationUpdate?(newLocation)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        requestLocationPermission()
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var recentPointsText: String = "No GPS points yet..."
    @State private var isLoading: Bool = false
    @State private var isWalkingMode: Bool = false
    @State private var showDebugView: Bool = false
    @State private var showPlacesList: Bool = false
    @State private var showMapDataInfo: Bool = false
    @State private var showPlaceEdit: Bool = false
    @State private var sharedPlaceData: (latitude: Double, longitude: Double, name: String?)?
    @State private var schematicData: SchematicMapData?
    @State private var debug: Bool = true
    @StateObject private var locationManager = LocationManager()
    @StateObject private var navigationService = NavigationService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if showDebugView {
                    debugView
                } else {
                    mainView
                }
            }
            .navigationTitle("Atlas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Places") {
                            showPlacesList = true
                        }
                        
                        Button("Import from Text") {
                            // This will be handled by share sheet now
                        }
                        
                        Divider()
                        
                        Button("Map Data") {
                            showMapDataInfo = true
                        }
                        
                        Divider()
                        
                        Button(showDebugView ? "Show Map" : "Show Debug") {
                            showDebugView.toggle()
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Auto")
                            Toggle("", isOn: $isWalkingMode)
                                .labelsHidden()
                            Text("Walking")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showPlacesList) {
            PlacesListView(currentLocation: locationManager.location)
        }
        .sheet(isPresented: $showMapDataInfo) {
            MapDataInfoView()
        }
        .sheet(isPresented: $showPlaceEdit) {
            if let sharedData = sharedPlaceData {
                PlaceEditViewWithPrefilledData(
                    latitude: sharedData.latitude,
                    longitude: sharedData.longitude,
                    name: sharedData.name,
                    currentLocation: locationManager.location
                )
            }
        }
        .onAppear {
            Task {
                await navigationService.initialize(modelContext: modelContext)
            }
            
            locationManager.onLocationUpdate = { location in
                Task {
                    await navigationService.calculateRoute(from: location, isWalkingMode: isWalkingMode)
                    await navigationService.calculateMatrixToClosestToilets(from: location, isWalkingMode: isWalkingMode)
                    await updateTraceAttributesAndSchematicData()
                    await updateRecentPointsText()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .incomingURL)) { notification in
            if let url = notification.object as? URL {
                handleIncomingURL(url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .incomingText)) { notification in
            if let text = notification.object as? String {
                handleIncomingText(text)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .incomingLocation)) { notification in
            if let locationData = notification.object as? (latitude: Double, longitude: Double, name: String?) {
                handleIncomingLocation(locationData)
            }
        }
        .onChange(of: schematicData) { _, newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue != nil && !showDebugView
        }
        .onChange(of: showDebugView) { _, newValue in
            UIApplication.shared.isIdleTimerDisabled = schematicData != nil && !newValue
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 10) {
            if let schematicData = schematicData {
                SchematicMapView(schematicData: schematicData, debug: debug, recentLocations: locationManager.recentLocations)
                    .frame(maxHeight: .infinity)
            } else {
                VStack {
                    Image(systemName: "location")
                        .imageScale(.large)
                        .foregroundStyle(.secondary)
                    Text("Getting GPS location...")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }
    
    private var debugView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Auto")
                    .foregroundColor(isWalkingMode ? .secondary : .primary)
                Toggle("", isOn: $isWalkingMode)
                    .labelsHidden()
                Text("Walking")
                    .foregroundColor(isWalkingMode ? .primary : .secondary)
            }
            .padding(.horizontal)
            
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            Text("Atlas GPS Routing")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView {
                VStack(spacing: 10) {
                    Text("Route Information:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(navigationService.routeResult)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text("Trace Attributes:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(navigationService.traceResult)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text("Matrix Results (Closest Toilets):")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(navigationService.matrixResult)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    
                    HStack {
                        Text("Recent GPS Points (for debugging):")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Copy") {
                            UIPasteboard.general.string = recentPointsText
                        }
                        .buttonStyle(.bordered)
                        .disabled(recentPointsText.isEmpty || recentPointsText == "No GPS points yet...")
                    }
                    
                    TextField("Recent GPS points...", text: $recentPointsText, axis: .vertical)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .lineLimit(10, reservesSpace: true)
                }
            }
        }
        .padding()
    }
    
    
    private func updateRecentPointsText() async {
        await MainActor.run {
            let points = locationManager.recentLocations.map { location in
                "(\(location.coordinate.latitude), \(location.coordinate.longitude))"
            }
            recentPointsText = "[\n" + points.joined(separator: ",\n") + "\n]"
        }
    }
    
    
    
    private func updateTraceAttributesAndSchematicData() async {
        if let response = await navigationService.getTraceAttributes(for: locationManager.recentLocations, isWalkingMode: isWalkingMode) {
            await MainActor.run {
                if response.edges?.isEmpty ?? true {
                    print(response)
                    return
                }
                schematicData = SchematicDataConverter.convertTraceAttributesToSchematicData(response, isWalkingMode: isWalkingMode, placeRoutes: navigationService.placeRoutes)
            }
        }
    }
    
    private func handleIncomingURL(_ url: URL) {
        if let decodedLocation = GE0URLDecoder.decode(url: url.absoluteString) {
            sharedPlaceData = (
                latitude: decodedLocation.latitude,
                longitude: decodedLocation.longitude,
                name: decodedLocation.name
            )
            showPlaceEdit = true
        }
    }
    
    private func handleIncomingText(_ text: String) {
        if let sharedData = SharedTextParser.parseSharedText(text) {
            sharedPlaceData = (
                latitude: sharedData.latitude,
                longitude: sharedData.longitude,
                name: sharedData.name
            )
            showPlaceEdit = true
        }
    }
    
    private func handleIncomingLocation(_ locationData: (latitude: Double, longitude: Double, name: String?)) {
        sharedPlaceData = (
            latitude: locationData.latitude,
            longitude: locationData.longitude,
            name: locationData.name
        )
        showPlaceEdit = true
    }
}

struct MapDataInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Map Data")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Map data from OpenStreetMap")
                        .font(.headline)
                    
                    Text("This app uses map data provided by OpenStreetMap, a collaborative project to create a free editable map of the world.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Link("Visit OpenStreetMap.org", destination: URL(string: "https://www.openstreetmap.org")!)
                        .font(.body)
                        .foregroundColor(.blue)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("License")
                        .font(.headline)
                    
                    Text("OpenStreetMap data is available under the Open Database License (ODbL).")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Link("View ODbL License", destination: URL(string: "https://opendatacommons.org/licenses/odbl/")!)
                        .font(.body)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PlaceEditViewWithPrefilledData: View {
    let latitude: Double
    let longitude: Double
    let name: String?
    let currentLocation: CLLocation?
    
    var body: some View {
        PlaceEditViewWithData(
            place: nil,
            currentLocation: currentLocation,
            prefilledLatitude: latitude,
            prefilledLongitude: longitude,
            prefilledName: name ?? ""
        )
    }
}

struct PlaceEditViewWithData: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let place: Place?
    let currentLocation: CLLocation?
    let prefilledLatitude: Double?
    let prefilledLongitude: Double?
    let prefilledName: String?
    
    @State private var emoji: String = "📍"
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
                        
                        if currentLocation != nil {
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
            .navigationTitle(isEditing ? "Edit Place" : "Add Shared Place")
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
        } else {
            // Use prefilled data for shared URLs
            if let prefilledLatitude = prefilledLatitude {
                latitude = prefilledLatitude
            } else if let currentLocation = currentLocation {
                latitude = currentLocation.coordinate.latitude
            }
            
            if let prefilledLongitude = prefilledLongitude {
                longitude = prefilledLongitude
            } else if let currentLocation = currentLocation {
                longitude = currentLocation.coordinate.longitude
            }
            
            if let prefilledName = prefilledName, !prefilledName.isEmpty {
                name = prefilledName
            }
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

#Preview {
    ContentView()
}
