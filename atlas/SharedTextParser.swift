//
//  SharedTextParser.swift
//  atlas
//
//  Created by Claude Code on 7/1/25.
//

import Foundation

struct SharedLocationData {
    let latitude: Double
    let longitude: Double
    let zoom: Int
    let name: String?
    let address: String?
    let phone: String?
    let originalURL: String
}

class SharedTextParser {
    static func parseSharedText(_ text: String) -> SharedLocationData? {
        // Look for supported URLs in the text
        let urlPattern = #"https?://(comaps\.at|omaps\.app|ge0\.me)/[^\s]+"#
        
        guard let regex = try? NSRegularExpression(pattern: urlPattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            return nil
        }
        
        let urlRange = Range(match.range, in: text)!
        let urlString = String(text[urlRange])
        
        // Try to decode the URL
        guard let decodedLocation = GE0URLDecoder.decode(url: urlString) else {
            return nil
        }
        
        // Extract additional information from the text
        let name = extractName(from: text, url: urlString)
        let address = extractAddress(from: text)
        let phone = extractPhone(from: text)
        
        return SharedLocationData(
            latitude: decodedLocation.latitude,
            longitude: decodedLocation.longitude,
            zoom: decodedLocation.zoom,
            name: name ?? decodedLocation.name,
            address: address,
            phone: phone,
            originalURL: urlString
        )
    }
    
    private static func extractName(from text: String, url: String) -> String? {
        // Split text into lines and try to find the name
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Skip lines that start with "Check out" or contain the URL
        let relevantLines = lines.filter { line in
            !line.hasPrefix("Check out") &&
            !line.contains("http") &&
            !line.contains("+1-") &&
            !line.contains("@") &&
            line.count > 2
        }
        
        // The first relevant line is likely the name
        return relevantLines.first
    }
    
    private static func extractAddress(from text: String) -> String? {
        // Look for address patterns (street names, numbers)
        let addressPattern = #"[A-Za-z\s]+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way),?\s*\d+"#
        
        guard let regex = try? NSRegularExpression(pattern: addressPattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            return nil
        }
        
        let addressRange = Range(match.range, in: text)!
        return String(text[addressRange])
    }
    
    private static func extractPhone(from text: String) -> String? {
        // Look for phone number patterns
        let phonePattern = #"\+?1?[-.\s]?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})"#
        
        guard let regex = try? NSRegularExpression(pattern: phonePattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
            return nil
        }
        
        let phoneRange = Range(match.range, in: text)!
        return String(text[phoneRange])
    }
}