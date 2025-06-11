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
    @State private var isLoading: Bool = false
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            Text("Atlas GPS Routing")
                .font(.title2)
                .fontWeight(.bold)
            
            ScrollView {
                Text(routeResult)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .onAppear {
            locationManager.onLocationUpdate = { location in
                Task {
                    await testValhallaRoute(from: location)
                }
            }
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
                costing: .auto,
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
}

#Preview {
    ContentView()
}
