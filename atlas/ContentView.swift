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
    
    // Test coordinates temporarily replacing live GPS
    private let testCoordinates = [
        (47.67327532420298, -122.38482069148498),
        (47.67326248046436, -122.38481523645135),
        (47.673246981674815, -122.38481710747024),
        (47.67323431487764, -122.38481102275948),
        (47.67321896106685, -122.38481719916645),
        (47.673204776431334, -122.38480377727599),
        (47.67319307481996, -122.38480326673842),
        (47.67318412615767, -122.38481887379062),
        (47.673171402564854, -122.38481686617965),
        (47.67315869744424, -122.38482143130629),
        (47.67314375025051, -122.38481791277368),
        (47.67312791238873, -122.38482285980876),
        (47.67311654307077, -122.38482456842144),
        (47.67310305210005, -122.38483168912074),
        (47.67309213606241, -122.38483367129723)
    ]
    private var testIndex = 0
    private var testTimer: Timer?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
        
        // Comment out live GPS for testing
        // requestLocationPermission()
        
        // Start test coordinate simulation
        startTestLocationUpdates()
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
    
    // Test location simulation
    func startTestLocationUpdates() {
        testTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.simulateNextLocation()
        }
        // Send first location immediately
        simulateNextLocation()
    }
    
    func simulateNextLocation() {
        guard testIndex < testCoordinates.count else {
            testTimer?.invalidate()
            return
        }
        
        let coord = testCoordinates[testIndex]
        let testLocation = CLLocation(latitude: coord.0, longitude: coord.1)
        
        location = testLocation
        recentLocations.append(testLocation)
        if recentLocations.count > 15 {
            recentLocations.removeFirst()
        }
        
        onLocationUpdate?(testLocation)
        testIndex += 1
    }
    
    var onLocationUpdate: ((CLLocation) -> Void)?
    
    // Commented out for test coordinates
    /*
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
    */
}

struct ContentView: View {
    @State private var routeResult: String = "Getting location..."
    @State private var traceResult: String = "Waiting for GPS locations..."
    @State private var recentPointsText: String = "No GPS points yet..."
    @State private var isLoading: Bool = false
    @State private var isWalkingMode: Bool = false
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
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
        .onAppear {
            locationManager.onLocationUpdate = { location in
                Task {
                    await testValhallaRoute(from: location)
                    await testTraceAttributes()
                    await updateRecentPointsText()
                }
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
        do {
            // Create a basic Valhalla config (you'll need proper tiles for real routing)
            let config = try ValhallaConfig(tileExtractTar: Bundle.main.url(forResource: "valhalla_tiles", withExtension: "tar")!)
            
            // Initialize Valhalla
            let valhalla = try Valhalla(config)
            
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
        do {
            // Create a basic Valhalla config
            let config = try ValhallaConfig(tileExtractTar: Bundle.main.url(forResource: "valhalla_tiles", withExtension: "tar")!)
            
            // Initialize Valhalla
            let valhalla = try Valhalla(config)
            
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
}

#Preview {
    ContentView()
}
