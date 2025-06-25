import Foundation
import CoreLocation
import Valhalla
import ValhallaModels
import ValhallaConfigModels

@MainActor
class NavigationService: ObservableObject {
    @Published var routeResult: String = "Getting location..."
    @Published var traceResult: String = "Waiting for GPS locations..."
    
    private var valhalla: Valhalla?
    private let daycareLocation = CLLocationCoordinate2D(latitude: 47.669553, longitude: -122.363616)
    
    func initialize() async {
        do {
            let config = try ValhallaConfig(tileExtractTar: Bundle.main.url(forResource: "valhalla_tiles", withExtension: "tar")!)
            valhalla = try Valhalla(config)
        } catch {
            routeResult = "Failed to initialize Valhalla: \(error.localizedDescription)"
            traceResult = "Failed to initialize Valhalla: \(error.localizedDescription)"
        }
    }
    
    func calculateRoute(from location: CLLocation, isWalkingMode: Bool) async {
        guard let valhalla = valhalla else {
            routeResult = "Valhalla not initialized"
            return
        }
        
        do {
            let request = RouteRequest(
                locations: [
                    RoutingWaypoint(lat: location.coordinate.latitude, lon: location.coordinate.longitude, radius: 100),
                    RoutingWaypoint(lat: daycareLocation.latitude, lon: daycareLocation.longitude, radius: 100)
                ],
                costing: isWalkingMode ? .pedestrian : .auto,
                directionsOptions: DirectionsOptions(units: .mi)
            )
            
            let response = try valhalla.route(request: request)
            
            routeResult = """
            Route to Daycare:
            From: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))
            Status: \(response.trip.statusMessage ?? "Unknown")
            Distance: \(response.trip.summary.length ?? 0) miles
            Time: \(response.trip.summary.time ?? 0) seconds
            Updated: \(Date().formatted(date: .omitted, time: .standard))
            """
            
        } catch {
            routeResult = "Error: \(error.localizedDescription)"
        }
    }
    
    func getTraceAttributes(for locations: [CLLocation], isWalkingMode: Bool) async -> TraceAttributesResponse? {
        guard let valhalla = valhalla else {
            traceResult = "Valhalla not initialized"
            return nil
        }
        
        do {
            let waypoints = locations.map { location in
                MapMatchWaypoint(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            }
            
            guard waypoints.count >= 2 else {
                traceResult = "Need at least 2 GPS locations for trace attributes (\(waypoints.count)/2)"
                return nil
            }
            
            let request = TraceAttributesRequest(
                shape: waypoints,
                costing: isWalkingMode ? .pedestrian : .auto
            )
            
            let response = try valhalla.traceAttributes(request: request)
            
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
            
            return response
            
        } catch {
            traceResult = "Trace Error: \(error.localizedDescription)"
            return nil
        }
    }
}