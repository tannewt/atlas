//
//  atlasApp.swift
//  atlas
//
//  Created by Scott Shawcroft on 6/9/25.
//

import SwiftUI
import SwiftData
import AtlasLibrary

@main
struct atlasApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Place.self, TimeSlot.self])
        
        // Use app group container for shared data access
        do {
            let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.tech.chickadee.atlas")!
            let modelConfiguration = ModelConfiguration(schema: schema, url: appGroupURL.appendingPathComponent("Model.sqlite"))
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Fallback to default container if app group fails
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Handle custom URL scheme from share extension
        if url.scheme == "atlas" && url.host == "import" {
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let queryItems = components.queryItems {
                
                var latitude: Double?
                var longitude: Double?
                var name: String?
                
                for item in queryItems {
                    switch item.name {
                    case "lat":
                        latitude = Double(item.value ?? "")
                    case "lon":
                        longitude = Double(item.value ?? "")
                    case "name":
                        name = item.value
                    default:
                        break
                    }
                }
                
                if let lat = latitude, let lon = longitude {
                    let locationData = (latitude: lat, longitude: lon, name: name)
                    NotificationCenter.default.post(name: .incomingLocation, object: locationData)
                    return
                }
            }
        }
        
        // Handle other incoming URLs
        NotificationCenter.default.post(name: .incomingURL, object: url)
    }
}

extension Notification.Name {
    static let incomingURL = Notification.Name("incomingURL")
    static let incomingText = Notification.Name("incomingText")
    static let incomingLocation = Notification.Name("incomingLocation")
}
