//
//  GE0URLDecoderTests.swift
//  atlasTests
//
//  Created by Claude Code on 7/1/25.
//

import XCTest
@testable import atlas

final class GE0URLDecoderTests: XCTestCase {
    
    func testDecodeValidGE0URL() {
        // Test with the example URL from the user
        let testURL = "https://comaps.at/0pEr3T4p0T/JRA_Bike_Shop"
        
        let decoded = GE0URLDecoder.decode(url: testURL)
        
        XCTAssertNotNil(decoded, "Should successfully decode valid GE0 URL")
        
        guard let location = decoded else { return }
        
        // Verify coordinates match expected values
        XCTAssertEqual(location.latitude, 47.69084, accuracy: 0.00001, "Latitude should match expected value")
        XCTAssertEqual(location.longitude, -122.3709, accuracy: 0.0001, "Longitude should match expected value")
        XCTAssertEqual(location.zoom, 17, "Zoom level should be 17")
        XCTAssertEqual(location.name, "JRA Bike Shop", "Name should be extracted from URL")
    }
    
    func testDecodeGE0URLWithoutName() {
        // Test URL without name component
        let testURL = "https://comaps.at/0pEr3T4p0T"
        
        let decoded = GE0URLDecoder.decode(url: testURL)
        
        XCTAssertNotNil(decoded, "Should successfully decode GE0 URL without name")
        
        guard let location = decoded else { return }
        
        XCTAssertEqual(location.latitude, 47.69084, accuracy: 0.00001, "Latitude should match expected value")
        XCTAssertEqual(location.longitude, -122.3709, accuracy: 0.0001, "Longitude should match expected value")
        XCTAssertEqual(location.zoom, 17, "Zoom level should be 17")
        XCTAssertNil(location.name, "Name should be nil when not provided")
    }
    
    func testDecodeInvalidURL() {
        // Test with invalid URL
        let invalidURL = "https://example.com/invalid"
        
        let decoded = GE0URLDecoder.decode(url: invalidURL)
        
        XCTAssertNil(decoded, "Should return nil for invalid URL")
    }
    
    func testDecodeInvalidHost() {
        // Test with wrong host
        let wrongHostURL = "https://maps.google.com/0pEr3T4p0T"
        
        let decoded = GE0URLDecoder.decode(url: wrongHostURL)
        
        XCTAssertNil(decoded, "Should return nil for wrong host")
    }
    
    func testDecodeGE0MeURL() {
        // Test with ge0.me domain (alternative format)
        let ge0URL = "https://ge0.me/0pEr3T4p0T/Test_Location"
        
        let decoded = GE0URLDecoder.decode(url: ge0URL)
        
        XCTAssertNotNil(decoded, "Should successfully decode ge0.me URL")
        
        guard let location = decoded else { return }
        
        XCTAssertEqual(location.latitude, 47.69084, accuracy: 0.00001, "Latitude should match expected value")
        XCTAssertEqual(location.longitude, -122.3709, accuracy: 0.0001, "Longitude should match expected value")
        XCTAssertEqual(location.name, "Test Location", "Name should be extracted with underscores replaced")
    }
    
    func testDecodeEmptyEncodedPart() {
        // Test with empty encoded part
        let emptyURL = "https://comaps.at/"
        
        let decoded = GE0URLDecoder.decode(url: emptyURL)
        
        XCTAssertNil(decoded, "Should return nil for empty encoded part")
    }
    
    func testDecodeShortEncodedString() {
        // Test with very short encoded string (less than minimum required)
        let shortURL = "https://comaps.at/A"
        
        let decoded = GE0URLDecoder.decode(url: shortURL)
        
        // Should still work for single character (zoom only)
        XCTAssertNotNil(decoded, "Should handle short encoded strings")
    }
    
    func testDecodeOmapsAppURL() {
        // Test with omaps.app domain (another alternative format)
        let omapsURL = "https://omaps.app/4pEr14rWxo/Book_Exchange"
        
        let decoded = GE0URLDecoder.decode(url: omapsURL)
        
        XCTAssertNotNil(decoded, "Should successfully decode omaps.app URL")
        
        guard let location = decoded else { return }
        
        // Verify coordinates are reasonable (specific values will depend on the encoded data)
        XCTAssertTrue(location.latitude >= -90.0 && location.latitude <= 90.0, "Latitude should be in valid range")
        XCTAssertTrue(location.longitude >= -180.0 && location.longitude <= 180.0, "Longitude should be in valid range")
        XCTAssertTrue(location.zoom >= 0 && location.zoom <= 25, "Zoom should be in reasonable range")
        XCTAssertEqual(location.name, "Book Exchange", "Name should be extracted with underscores replaced")
    }
    
    func testDecodeUserProvidedOmapsURL() {
        // Test with the specific omaps.app URL provided by the user
        let userURL = "https://omaps.app/4pEr14rWxo/Book_Exchange"
        
        let decoded = GE0URLDecoder.decode(url: userURL)
        
        XCTAssertNotNil(decoded, "Should successfully decode user-provided omaps.app URL")
        
        guard let location = decoded else { return }
        
        print("Decoded omaps.app coordinates:")
        print("Latitude: \(location.latitude)")
        print("Longitude: \(location.longitude)")
        print("Zoom: \(location.zoom)")
        print("Name: \(location.name ?? "N/A")")
    }
}