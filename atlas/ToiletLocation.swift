import Foundation
import CoreLocation
import ValhallaModels

public struct ToiletLocation: Identifiable {
    public let id = UUID()
    public let coordinate: CLLocationCoordinate2D
    public let properties: ToiletProperties
    
    public init(coordinate: CLLocationCoordinate2D, properties: ToiletProperties) {
        self.coordinate = coordinate
        self.properties = properties
    }
    
    // Convert to Valhalla Coordinate
    public var valhallaCoordinate: Coordinate {
        return Coordinate(lat: coordinate.latitude, lon: coordinate.longitude)
    }
    
    // Calculate distance from another coordinate
    public func distance(from location: CLLocation) -> Double {
        let toiletLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: toiletLocation)
    }
}

public struct ToiletProperties: Codable {
    public let amenity: String?
    public let osmId: Int?
    public let osmType: String?
    public let access: String?
    public let fee: String?
    public let wheelchair: String?
    public let description: String?
    public let name: String?
    public let operatorName: String?
    public let containingAreaName: String?
    
    private enum CodingKeys: String, CodingKey {
        case amenity
        case osmId = "osm_id"
        case osmType = "osm_type"
        case access, fee, wheelchair, description, name
        case operatorName = "operator"
        case containingAreaName = "containing_area_name"
    }
}

public struct ToiletFeatureCollection: Codable {
    public let type: String
    public let features: [ToiletFeature]
}

public struct ToiletFeature: Codable {
    public let type: String
    public let geometry: Geometry
    public let properties: ToiletProperties
    
    public var toiletLocation: ToiletLocation {
        return ToiletLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: geometry.coordinates[1],
                longitude: geometry.coordinates[0]
            ), 
            properties: properties
        )
    }
}

public struct Geometry: Codable {
    public let type: String
    public let coordinates: [Double]
}