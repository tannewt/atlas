import Foundation
import CoreLocation
import Valhalla
import ValhallaModels
import ValhallaConfigModels
import SwiftData
import AtlasLibrary

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
    @Published var matrixResult: String = "No matrix calculations yet..."
    
    private var valhalla: Valhalla?
    private var modelContext: ModelContext?
    private var toiletLocations: [ToiletLocation] = []
    
    func initialize(modelContext: ModelContext? = nil) async {
        self.modelContext = modelContext
        do {
            let config = try ValhallaConfig(tileExtractTar: Bundle.main.url(forResource: "valhalla_tiles", withExtension: "tar")!)
            valhalla = try Valhalla(config)
            await loadToiletLocations()
        } catch {
            routeResult = "Failed to initialize Valhalla: \(error.localizedDescription)"
            traceResult = "Failed to initialize Valhalla: \(error.localizedDescription)"
            matrixResult = "Failed to initialize Valhalla: \(error.localizedDescription)"
        }
    }
    
    private func loadToiletLocations() async {
        print("Loading toilet locations...")
        let url = Bundle.main.url(forResource: "seattle-toilets", withExtension: "geojson")!
        
        do {
            print("Loading toilet locations from \(url)")
            let data = try Data(contentsOf: url)
            print("Data size: \(data.count)")
            let featureCollection = try JSONDecoder().decode(ToiletFeatureCollection.self, from: data)
            toiletLocations = featureCollection.features.map { $0.toiletLocation }
            matrixResult = "Loaded \(toiletLocations.count) toilet locations"
            print("Loaded \(toiletLocations.count) toilet locations")
        } catch {
            matrixResult = "Failed to load toilet locations: \(error.localizedDescription)"
            print(error)
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
    
    func calculateMatrixToClosestToilets(from location: CLLocation, isWalkingMode: Bool) async {
        guard let valhalla = valhalla else {
            matrixResult = "Valhalla not initialized"
            return
        }
        
        guard !toiletLocations.isEmpty else {
            matrixResult = "No toilet locations loaded"
            return
        }
        
        // Find the closest 10 toilets by straight-line distance
        let sortedToilets = toiletLocations
            .map { toilet in
                (toilet: toilet, distance: toilet.distance(from: location))
            }
            .sorted { $0.distance < $1.distance }
            .prefix(10)
            .map { $0.toilet }
        
        do {
            let sourceCoordinate = Coordinate(lat: location.coordinate.latitude, lon: location.coordinate.longitude)
            let targetCoordinates = sortedToilets.map { $0.valhallaCoordinate }
            
            // Print GeoJSON with current location and 10 nearest toilets
            printGeoJSON(currentLocation: location, toilets: sortedToilets)
            let request = MatrixRequest(
                sources: [sourceCoordinate],
                targets: targetCoordinates,
                costing: isWalkingMode ? .pedestrian : .auto,
                matrixLocations: 1,
                units: .mi,
            )
            
            let response = try valhalla.matrix(request: request)
            
            var result = "Matrix calculation to closest 10 toilets:\n"
            result += "From: \(String(format: "%.6f", location.coordinate.latitude)), \(String(format: "%.6f", location.coordinate.longitude))\n\n"
            
            if let distances = response.sourcesToTargets.first {
                for (index, distance) in distances.enumerated() {
                    let toilet = sortedToilets[index]
                    let properties = toilet.properties
                    let name = properties.name ?? properties.containingAreaName ?? "Toilet"
                    let access = properties.access ?? "unknown"
                    let wheelchairAccess = properties.wheelchair ?? "unknown"
                    
                    result += "\(index + 1). \(name)\n"
                    result += "   Distance: \(String(format: "%.2f", distance.distance ?? 0)) mi\n"
                    result += "   Time: \(Int((distance.time ?? 0) / 60)) min\n"
                    result += "   Access: \(access), Wheelchair: \(wheelchairAccess)\n"
                    result += "   Location: (\(String(format: "%.6f", toilet.coordinate.latitude)), \(String(format: "%.6f", toilet.coordinate.longitude)))\n\n"
                }
            }
            
            result += "Updated: \(Date().formatted(date: .omitted, time: .standard))"
            matrixResult = result
            
            // Find the nearest toilet based on matrix result (routing time)
            if let distances = response.sourcesToTargets.first {
                let toiletDistancePairs = distances.enumerated().compactMap { (index, distance) -> (ToiletLocation, Double, Int)? in
                    return (sortedToilets[index], distance.distance, distance.time)
                }
                
                // Sort by routing time (matrix result) to find the actual nearest
                let sortedByRoutingTime = toiletDistancePairs.sorted { $0.2 < $1.2 }
                
                if let nearestByRouting = sortedByRoutingTime.first {
                    do {
                        let routeRequest = RouteRequest(
                            locations: [
                                RoutingWaypoint(lat: location.coordinate.latitude, lon: location.coordinate.longitude, radius: 100),
                                RoutingWaypoint(lat: nearestByRouting.0.coordinate.latitude, lon: nearestByRouting.0.coordinate.longitude, radius: 100)
                            ],
                            costing: isWalkingMode ? .pedestrian : .auto,
                            directionsOptions: DirectionsOptions(units: .mi)
                        )
                        
                        let routeResponse = try valhalla.route(request: routeRequest)
                        
                        // Convert toilet to a temporary Place for consistency with existing PlaceRouteInfo system
                        let toiletAsPlace = Place(
                            emoji: "🚽",
                            name: nearestByRouting.0.properties.name ?? nearestByRouting.0.properties.containingAreaName ?? "Nearest Toilet",
                            latitude: nearestByRouting.0.coordinate.latitude,
                            longitude: nearestByRouting.0.coordinate.longitude,
                            showPolicy: .always,
                            nearbyDistance: 0
                        )
                        
                        let toiletPlaceRoute = PlaceRouteInfo(
                            place: toiletAsPlace,
                            routeResponse: routeResponse,
                            distance: routeResponse.trip.summary.length,
                            time: routeResponse.trip.summary.time
                        )
                        
                        // Add to placeRoutes or store separately - let's add it to existing placeRoutes
                        placeRoutes.append(toiletPlaceRoute)
                    } catch {
                        print("Failed to get route to nearest toilet: \(error.localizedDescription)")
                    }
                }
            }
            
        } catch {
            matrixResult = "Matrix Error: \(error.localizedDescription)"
        }
    }
    
    private func printGeoJSON(currentLocation: CLLocation, toilets: [ToiletLocation]) {
        var features: [[String: Any]] = []
        
        // Add current location as a feature
        let currentLocationFeature: [String: Any] = [
            "type": "Feature",
            "geometry": [
                "type": "Point",
                "coordinates": [currentLocation.coordinate.longitude, currentLocation.coordinate.latitude]
            ],
            "properties": [
                "name": "Current Location",
                "type": "current_location"
            ]
        ]
        features.append(currentLocationFeature)
        
        // Add toilet locations as features
        for (index, toilet) in toilets.enumerated() {
            let toiletFeature: [String: Any] = [
                "type": "Feature",
                "geometry": [
                    "type": "Point",
                    "coordinates": [toilet.coordinate.longitude, toilet.coordinate.latitude]
                ],
                "properties": [
                    "name": toilet.properties.name ?? toilet.properties.containingAreaName ?? "Toilet \(index + 1)",
                    "type": "toilet",
                    "access": toilet.properties.access ?? "unknown",
                    "wheelchair": toilet.properties.wheelchair ?? "unknown",
                    "rank": index + 1
                ]
            ]
            features.append(toiletFeature)
        }
        
        let geoJSON: [String: Any] = [
            "type": "FeatureCollection",
            "features": features
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: geoJSON, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            print("GeoJSON with current location and 10 nearest toilets:")
            print(jsonString)
        }
    }
}
