//
//  GE0URLDecoder.swift
//  atlas
//
//  Created by Claude Code on 7/1/25.
//

import Foundation

struct DecodedLocation {
    let latitude: Double
    let longitude: Double
    let zoom: Int
    let name: String?
}

class GE0URLDecoder {
    private static let base64Characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    
    static func decode(url: String) -> DecodedLocation? {
        guard let urlComponents = URLComponents(string: url),
              let host = urlComponents.host,
              host == "comaps.at" || host == "ge0.me" || host == "omaps.app" else {
            return nil
        }
        
        let path = urlComponents.path
        let pathComponents = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        guard let encodedPart = pathComponents.first else {
            return nil
        }
        
        // Extract name if present
        let name = pathComponents.count > 1 ? pathComponents[1].replacingOccurrences(of: "_", with: " ") : nil
        
        return decodeGE0String(encodedPart, name: name)
    }
    
    private static func decodeGE0String(_ encoded: String, name: String?) -> DecodedLocation? {
        guard encoded.count >= 1 else { return nil }
        
        var bytes: [UInt8] = []
        
        // Convert base64-like string to bytes
        for char in encoded {
            guard let index = base64Characters.firstIndex(of: char) else {
                return nil
            }
            bytes.append(UInt8(base64Characters.distance(from: base64Characters.startIndex, to: index)))
        }
        
        guard bytes.count >= 1 else { return nil }
        
        // Extract zoom level from first character
        let zoom = Int(round(Double(bytes[0]) / 4.0 + 4.0))
        
        // Constants from ge0 format
        let GE0_MAX_COORD_BITS = 31
        let GE0_MAX_POINT_BYTES = 10
        
        let latLonBytes = min(bytes.count - 1, GE0_MAX_POINT_BYTES)
        
        var lat: UInt64 = 0
        var lon: UInt64 = 0
        
        // Decode coordinates using interleaved bits pattern from organicmaps
        for i in 0..<latLonBytes {
            let shift = GE0_MAX_COORD_BITS - 3 - (i * 3)
            if shift < 0 { break }
            
            let a = bytes[i + 1] // Skip first zoom byte
            
            // Extract latitude bits (bits 5, 3, 1)
            let lat1 = (((a >> 5) & 1) << 2) | (((a >> 3) & 1) << 1) | ((a >> 1) & 1)
            
            // Extract longitude bits (bits 4, 2, 0)
            let lon1 = (((a >> 4) & 1) << 2) | (((a >> 2) & 1) << 1) | (a & 1)
            
            lat |= UInt64(lat1) << shift
            lon |= UInt64(lon1) << shift
        }
        
        // Add middle of square adjustment
        let middleOfSquare = 1 << (3 * (GE0_MAX_POINT_BYTES - latLonBytes) - 1)
        lat += UInt64(middleOfSquare)
        lon += UInt64(middleOfSquare)
        
        // Convert to geographic coordinates
        let maxCoordValue = (1 << GE0_MAX_COORD_BITS) - 1
        let latitude = (Double(lat) / Double(maxCoordValue)) * 180.0 - 90.0
        let longitude = (Double(lon) / Double(1 << GE0_MAX_COORD_BITS)) * 360.0 - 180.0
        
        // Round to 5 decimal places
        let roundedLat = round(latitude * 100000.0) / 100000.0
        let roundedLon = round(longitude * 100000.0) / 100000.0
        
        return DecodedLocation(
            latitude: roundedLat,
            longitude: roundedLon,
            zoom: zoom,
            name: name
        )
    }
}