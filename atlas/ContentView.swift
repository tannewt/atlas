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
    @State private var schematicData: SchematicMapData?
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
        .onAppear {
            Task {
                await navigationService.initialize(modelContext: modelContext)
            }
            
            locationManager.onLocationUpdate = { location in
                Task {
                    await navigationService.calculateRoute(from: location, isWalkingMode: isWalkingMode)
                    await updateTraceAttributesAndSchematicData()
                    await updateRecentPointsText()
                }
            }
        }
    }
    
    private var mainView: some View {
        VStack(spacing: 10) {
            if let schematicData = schematicData {
                SchematicMapView(schematicData: schematicData)
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
                schematicData = SchematicDataConverter.convertTraceAttributesToSchematicData(response, isWalkingMode: isWalkingMode, placeRoutes: navigationService.placeRoutes)
            }
        }
    }
}

#Preview {
    ContentView()
}
