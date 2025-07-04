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
    @State private var routeResult: String = "Getting location..."
    @State private var traceResult: String = "Waiting for GPS locations..."
    @State private var recentPointsText: String = "No GPS points yet..."
    @State private var isLoading: Bool = false
    @State private var isWalkingMode: Bool = false
    @State private var showDebugView: Bool = false
    @State private var schematicData: SchematicMapData?
    @StateObject private var locationManager = LocationManager()
    @State private var valhalla: Valhalla?
    
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
        .onAppear {
            Task {
                await initializeValhalla()
            }
            
            locationManager.onLocationUpdate = { location in
                Task {
                    await testValhallaRoute(from: location)
                    await testTraceAttributes()
                    await updateRecentPointsText()
                    await updateSchematicData()
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
                    
                    Text(routeResult)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text("Trace Attributes:")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(traceResult)
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
    
    private func initializeValhalla() async {
        do {
            let config = try ValhallaConfig(tileExtractTar: Bundle.main.url(forResource: "valhalla_tiles", withExtension: "tar")!)
            valhalla = try Valhalla(config)
        } catch {
            await MainActor.run {
                routeResult = "Failed to initialize Valhalla: \(error.localizedDescription)"
                traceResult = "Failed to initialize Valhalla: \(error.localizedDescription)"
            }
        }
    }
    
    private func updateRecentPointsText() async {
        await MainActor.run {
            let points = locationManager.recentLocations.map { location in
                "(\(location.coordinate.latitude), \(location.coordinate.longitude))"
            }
            recentPointsText = "[\n" + points.joined(separator: ",\n") + "\n]"
        }
    }
    
    private func testValhallaRoute(from location: CLLocation) async {
        guard let valhalla = valhalla else {
            await MainActor.run {
                routeResult = "Valhalla not initialized"
            }
            return
        }
        
        do {
            
            // Create a route request from current location to daycare
            let request = RouteRequest(
                locations: [
                    RoutingWaypoint(lat: location.coordinate.latitude, lon: location.coordinate.longitude, radius: 100), // Current GPS location
                    RoutingWaypoint(lat: 47.669553, lon: -122.363616, radius: 100)  // Daycare
                ],
                costing: isWalkingMode ? .pedestrian : .auto,
                directionsOptions: DirectionsOptions(units: .mi)
            )
            
            // Get the route
            let response = try valhalla.route(request: request)
            
            await MainActor.run {
                routeResult = """
                Route to Daycare:
                From: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))
                Status: \(response.trip.statusMessage ?? "Unknown")
                Distance: \(response.trip.summary.length ?? 0) miles
                Time: \(response.trip.summary.time ?? 0) seconds
                Updated: \(Date().formatted(date: .omitted, time: .standard))
                """
            }
            
        } catch {
            await MainActor.run {
                routeResult = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func testTraceAttributes() async {
        guard let valhalla = valhalla else {
            await MainActor.run {
                traceResult = "Valhalla not initialized"
            }
            return
        }
        
        do {
            
            // Use last 15 GPS locations instead of hardcoded waypoints
            let waypoints = locationManager.recentLocations.map { location in
                MapMatchWaypoint(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            }
            
            // Need at least 2 locations for trace attributes
            guard waypoints.count >= 2 else {
                await MainActor.run {
                    traceResult = "Need at least 2 GPS locations for trace attributes (\(waypoints.count)/2)"
                }
                return
            }
            
            // Create trace attributes request
            let request = TraceAttributesRequest(
                shape: waypoints,
                costing: isWalkingMode ? .pedestrian : .auto
            )
            
            // Get trace attributes
            let response = try valhalla.traceAttributes(request: request)
            
            await MainActor.run {
                var result = "Trace Attributes (\(waypoints.count) locations):\n"
                result += "Match confidence: \(String(format: "%.2f", response.confidenceScore ?? 0))\n"
                result += "Matched points: \(response.matchedPoints?.count ?? 0)\n"
                result += "Road segments: \(response.edges?.count ?? 0)\n\n"
                
                if let edges = response.edges?.prefix(3) {
                    result += "Recent road segments:\n"
                    for (index, edge) in edges.enumerated() {
                        result += "\(index + 1). "
                        if let names = edge.names, !names.isEmpty {
                            result += "\(names.joined(separator: ", "))"
                        } else {
                            result += "Unnamed road"
                        }
                        
                        if let length = edge.length {
                            result += " (\(String(format: "%.2f", length)) mi)"
                        }
                        
                        if let speed = edge.speed {
                            result += " \(speed) mph"
                        }
                        
                        if let speedLimit = edge.speedLimit {
                            result += " (limit: \(speedLimit) mph)"
                        }
                        
                        result += "\n"
                    }
                }
                
                result += "\nUpdated: \(Date().formatted(date: .omitted, time: .standard))"
                traceResult = result
            }
            
        } catch {
            await MainActor.run {
                traceResult = "Trace Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func updateSchematicData() async {
        guard let valhalla = valhalla else { return }
        
        do {
            let waypoints = locationManager.recentLocations.map { location in
                MapMatchWaypoint(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            }
            
            guard waypoints.count >= 2 else { return }
            
            let request = TraceAttributesRequest(
                shape: waypoints,
                costing: isWalkingMode ? .pedestrian : .auto
            )
            
            let response = try valhalla.traceAttributes(request: request)
            
            await MainActor.run {
                // Convert trace attributes to SchematicMapData
                let currentRoadName = response.edges?.first?.names?.first ?? "Unknown Road"
                
                // Create cross streets from edges data
                var crossStreets: [CrossStreetIntersection] = []
                
                if let edges = response.edges {
                    var currentDistance: Double = 0
                    
                    for (index, edge) in edges.enumerated() {
                        if index >= response.matchedPoints?[-1].edgeIndex ?? 0, let edgeLength = edge.length {
                            currentDistance += edgeLength * 1609.34 // Convert miles to meters
                            
                            if let intersectingEdges = edge.endNode?.intersectingEdges, !intersectingEdges.isEmpty,
                               let endHeading = edge.endHeading {
                                let validIntersectingEdges = intersectingEdges.filter { intersecting in
                                    intersecting.beginHeading != nil && 
                                    (intersecting.driveability == .forward || intersecting.driveability == .both)
                                }
                                
                                if !validIntersectingEdges.isEmpty {
                                    let intersection = CrossStreetIntersection(
                                        distanceAhead: currentDistance,
                                        streets: validIntersectingEdges.map { intersecting in
                                            let beginHeading = intersecting.beginHeading!
                                            let headingDiff = endHeading - beginHeading + 360
                                            let normalizedHeading = headingDiff % 360 - 180
                                            return CrossStreet(names: intersecting.names, heading: normalizedHeading)
                                        }
                                    )
                                    crossStreets.append(intersection)
                                }
                            }
                        }
                    }
                }
                
                schematicData = SchematicMapData(
                    currentRoad: currentRoadName,
                    crossStreets: Array(crossStreets.prefix(5)) // Limit to 5 upcoming intersections
                )
            }
            
        } catch {
            // Silent fail for schematic data updates
        }
    }
}

#Preview {
    ContentView()
}
