import Foundation
import CoreLocation
import Valhalla
import ValhallaModels
import ValhallaConfigModels
import SwiftData

struct PlaceRouteInfo {
    let place: Place
    let routeResponse: RouteResponse
    let distance: Double
    let time: Double
}

@MainActor
class NavigationService: ObservableObject {
    @Published var routeResult: String = "Getting location..."
    @Published var traceResult: String = "Waiting for GPS locations..."
    @Published var placeRoutes: [PlaceRouteInfo] = []
    
    private var valhalla: Valhalla?
    private var modelContext: ModelContext?
    
    func initialize(modelContext: ModelContext? = nil) async {
        self.modelContext = modelContext
        do {
            let config = try ValhallaConfig(tileExtractTar: Bundle.main.url(forResource: "valhalla_tiles", withExtension: "tar")!)
            valhalla = try Valhalla(config)
        } catch {
            routeResult = "Failed to initialize Valhalla: \(error.localizedDescription)"
            traceResult = "Failed to initialize Valhalla: \(error.localizedDescription)"
        }
    }
    
    private func getActivePlaces(from currentLocation: CLLocation) -> [Place] {
        guard let modelContext = modelContext else { return [] }
        
        let fetchDescriptor = FetchDescriptor<Place>()
        guard let places = try? modelContext.fetch(fetchDescriptor) else { return [] }
        
        let currentDate = Date()
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: currentDate)
        let currentHour = calendar.component(.hour, from: currentDate)
        let currentMinute = calendar.component(.minute, from: currentDate)
        
        return places.filter { place in
            switch place.showPolicy {
            case .always:
                return true
            case .never:
                return false
            case .nearby:
                let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
                let distance = currentLocation.distance(from: placeLocation) / 1609.34 // Convert to miles
                return distance <= place.nearbyDistance
            case .atCertainTimes:
                return place.timeSlots.contains { timeSlot in
                    guard timeSlot.daysOfWeek.contains(currentWeekday) else { return false }
                    
                    let startMinutes = timeSlot.startHour * 60 + timeSlot.startMinute
                    let endMinutes = timeSlot.endHour * 60 + timeSlot.endMinute
                    let currentMinutes = currentHour * 60 + currentMinute
                    
                    return currentMinutes >= startMinutes && currentMinutes <= endMinutes
                }
            }
        }
    }
    
    func calculateRoute(from location: CLLocation, isWalkingMode: Bool) async {
        guard let valhalla = valhalla else {
            routeResult = "Valhalla not initialized"
            return
        }
        
        let activePlaces = getActivePlaces(from: location)
        
        guard !activePlaces.isEmpty else {
            routeResult = """
            No active places to route to.
            From: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))
            Updated: \(Date().formatted(date: .omitted, time: .standard))
            """
            return
        }
        
        var routeResults: [String] = []
        var newPlaceRoutes: [PlaceRouteInfo] = []
        
        for place in activePlaces {
            do {
                let request = RouteRequest(
                    locations: [
                        RoutingWaypoint(lat: location.coordinate.latitude, lon: location.coordinate.longitude, radius: 100),
                        RoutingWaypoint(lat: place.latitude, lon: place.longitude, radius: 100)
                    ],
                    costing: isWalkingMode ? .pedestrian : .auto,
                    directionsOptions: DirectionsOptions(units: .mi)
                )
                
                let response = try valhalla.route(request: request)
                
                let result = """
                \(place.emoji) \(place.name):
                Distance: \(String(format: "%.2f", response.trip.summary.length)) miles
                Time: \(Int(response.trip.summary.time) / 60) min
                """
                routeResults.append(result)
                
                // Store the route information for schematic map use
                let placeRouteInfo = PlaceRouteInfo(
                    place: place,
                    routeResponse: response,
                    distance: response.trip.summary.length,
                    time: response.trip.summary.time
                )
                newPlaceRoutes.append(placeRouteInfo)
                
            } catch {
                routeResults.append("\(place.emoji) \(place.name): Error - \(error.localizedDescription)")
            }
        }
        
        placeRoutes = newPlaceRoutes
        
        routeResult = """
        Routes from current location:
        From: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))
        
        \(routeResults.joined(separator: "\n\n"))
        
        Updated: \(Date().formatted(date: .omitted, time: .standard))
        """
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