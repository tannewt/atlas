import Foundation
import ValhallaModels

struct SchematicDataConverter {
    static func convertTraceAttributesToSchematicData(_ response: TraceAttributesResponse, isWalkingMode: Bool) -> SchematicMapData? {
        let currentRoadName = response.edges?.first?.names?.first ?? "Unknown Road"
        
        var crossStreets: [CrossStreetIntersection] = []
        
        guard let edges = response.edges else {
            return SchematicMapData(currentRoad: currentRoadName, crossStreets: [])
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
                                return CrossStreet(names: intersecting.names, heading: normalizedHeading, sign: intersecting.sign)
                            }
                        )
                        crossStreets.append(intersection)
                    }
                }
            }
        }
        
        return SchematicMapData(
            currentRoad: currentRoadName,
            crossStreets: Array(crossStreets.prefix(5)) // Limit to 5 upcoming intersections
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
}