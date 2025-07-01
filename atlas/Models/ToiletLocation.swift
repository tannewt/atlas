import Foundation
import CoreLocation
import ValhallaModels

struct ToiletLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let properties: ToiletProperties
    
    // Convert to Valhalla Coordinate
    var valhallaCoordinate: Coordinate {
        return Coordinate(lat: coordinate.latitude, lon: coordinate.longitude)
    }
    
    // Calculate distance from another coordinate
    func distance(from location: CLLocation) -> Double {
        let toiletLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: toiletLocation)
    }
}

struct ToiletProperties: Codable {
    let amenity: String?
    let osmId: Int?
    let osmType: String?
    let access: String?
    let fee: String?
    let wheelchair: String?
    let description: String?
    let name: String?
    let operatorName: String?
    
    private enum CodingKeys: String, CodingKey {
        case amenity
        case osmId = "osm_id"
        case osmType = "osm_type"
        case access, fee, wheelchair, description, name
        case operatorName = "operator"
    }
}

struct ToiletFeatureCollection: Codable {
    let type: String
    let features: [ToiletFeature]
}

struct ToiletFeature: Codable {
    let type: String
    let geometry: Geometry
    let properties: ToiletProperties
    
    var toiletLocation: ToiletLocation {
        return ToiletLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: geometry.coordinates[1],
                longitude: geometry.coordinates[0]
            ), 
            properties: properties
        )
    }
}

struct Geometry: Codable {
    let type: String
    let coordinates: [Double]
}