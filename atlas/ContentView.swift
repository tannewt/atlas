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

struct ContentView: View {
    @State private var routeResult: String = "Tap to test route"
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            
            Text("Valhalla Route Test")
                .font(.title2)
                .fontWeight(.bold)
            
            Button(action: testRoute) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "Testing Route..." : "Test Route")
                }
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(isLoading)
            
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
    }
    
    private func testRoute() {
        isLoading = true
        routeResult = "Testing local Valhalla route..."
        
        Task {
            await testValhallaRoute()
        }
    }
    
    private func testValhallaRoute() async {
        do {
            // Create a basic Valhalla config (you'll need proper tiles for real routing)
            let config = try ValhallaConfig(tileExtractTar: Bundle.main.url(forResource: "valhalla_tiles", withExtension: "tar")!)
            
            // Initialize Valhalla
            let valhalla = try Valhalla(config)
            
            // Create a route request
            let request = RouteRequest(
                locations: [
                    RoutingWaypoint(lat: 47.674583, lon: -122.385132, radius: 100), // HOme
                    RoutingWaypoint(lat: 47.669553, lon: -122.363616, radius: 100)  // Daycare
                ],
                costing: .auto,
                directionsOptions: DirectionsOptions(units: .mi)
            )
            
            // Get the route
            let response = try valhalla.route(request: request)
            
            await MainActor.run {
                routeResult = """
                Route found!
                Status: \(response.trip.statusMessage ?? "Unknown")
                Distance: \(response.trip.summary.length ?? 0) miles
                Time: \(response.trip.summary.time ?? 0) seconds
                Legs: \(response.trip.legs.count)
                """
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                routeResult = "Error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
}
