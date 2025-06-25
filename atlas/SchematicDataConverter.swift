import Foundation
import ValhallaModels

struct SchematicDataConverter {
    static func convertTraceAttributesToSchematicData(_ response: TraceAttributesResponse, isWalkingMode: Bool, placeRoutes: [PlaceRouteInfo] = []) -> SchematicMapData? {
        let currentRoadName = response.edges?.first?.names?.first ?? "Unknown Road"
        
        var crossStreets: [CrossStreetIntersection] = []
        
        guard let edges = response.edges else {
            return SchematicMapData(currentRoad: currentRoadName, crossStreets: [], straightAheadPlaces: [])
        }
        
        var currentDistance: Double = 0
        
        for (index, edge) in edges.enumerated() {
            if index >= response.matchedPoints?.last?.edgeIndex ?? 0, let edgeLength = edge.length {
                currentDistance += edgeLength * 1609.34 // Convert miles to meters
                
                if let intersectingEdges = edge.endNode?.intersectingEdges, !intersectingEdges.isEmpty,
                   let endHeading = edge.endHeading {
                    let validIntersectingEdges = filterDriveableEdges(intersectingEdges)
                    
                    if !validIntersectingEdges.isEmpty {
                        let intersection = CrossStreetIntersection(
                            distanceAhead: currentDistance,
                            streets: validIntersectingEdges.map { intersecting in
                                let beginHeading = intersecting.beginHeading!
                                let normalizedHeading = calculateRelativeHeading(endHeading: Double(endHeading), beginHeading: Double(beginHeading))
                                
                                // Check if any place routes diverge at this intersecting edge
                                let placeInfos = findPlaceRoutesForEdge(intersecting.edgeId, placeRoutes: placeRoutes)
                                
                                return CrossStreet(names: intersecting.names, heading: normalizedHeading, sign: intersecting.sign, placeInfos: placeInfos)
                            }
                        )
                        crossStreets.append(intersection)
                    }
                }
            }
        }
        
        // Check if the last trace edge is part of any place routes (straight ahead)
        let straightAheadPlaces = findStraightAheadPlaces(edges: edges, placeRoutes: placeRoutes)
        
        return SchematicMapData(
            currentRoad: currentRoadName,
            crossStreets: crossStreets,
            straightAheadPlaces: straightAheadPlaces
        )
    }
    
    private static func filterDriveableEdges(_ intersectingEdges: [IntersectingEdge]) -> [IntersectingEdge] {
        return intersectingEdges.filter { intersecting in
            intersecting.beginHeading != nil &&
            (intersecting.driveability == .forward || intersecting.driveability == .both)
        }
    }
    
    private static func calculateRelativeHeading(endHeading: Double, beginHeading: Double) -> Int {
        let headingDiff = endHeading - beginHeading + 360
        let normalizedHeading = headingDiff.truncatingRemainder(dividingBy: 360) - 180
        return Int(normalizedHeading)
    }
    
    private static func findPlaceRoutesForEdge(_ edgeId: Int64?, placeRoutes: [PlaceRouteInfo]) -> [PlaceInfo] {
        guard let edgeId = edgeId else { return [] }
        
        var placeInfos: [PlaceInfo] = []
        
        for placeRoute in placeRoutes {
            // Check if this edge ID appears in any of the route legs
            for leg in placeRoute.routeResponse.trip.legs {
                if leg.edgeIds.contains(edgeId) {
                    let placeInfo = PlaceInfo(
                        place: placeRoute.place,
                        distance: placeRoute.distance,
                        time: placeRoute.time
                    )
                    placeInfos.append(placeInfo)
                    break // Only add once per place
                }
            }
        }
        
        return placeInfos
    }
    
    private static func findStraightAheadPlaces(edges: [TraceEdge], placeRoutes: [PlaceRouteInfo]) -> [PlaceInfo] {
        guard let lastEdge = edges.last, let lastEdgeId = lastEdge.id else { return [] }
        
        var straightAheadPlaces: [PlaceInfo] = []
        
        for placeRoute in placeRoutes {
            print("Place Route: \(placeRoute.place.name)")
            // Check if the last trace edge is part of this place's route
            for leg in placeRoute.routeResponse.trip.legs {
                // Print out edges ids and leg edge ids until they differ
                for i in 0..<min(leg.edgeIds.count, edges.count) {
                    print("Edge ID: \(edges[i].id) Leg Edge ID: \(leg.edgeIds[i])")
                    if edges[i].id != leg.edgeIds[i] {
                        break
                    }
                }
                if leg.edgeIds.contains(lastEdgeId) {
                    let placeInfo = PlaceInfo(
                        place: placeRoute.place,
                        distance: placeRoute.distance,
                        time: placeRoute.time
                    )
                    straightAheadPlaces.append(placeInfo)
                    break // Only add once per place
                }
            }
        }
        
        return straightAheadPlaces
    }
}
