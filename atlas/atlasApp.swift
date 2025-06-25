//
//  atlasApp.swift
//  atlas
//
//  Created by Scott Shawcroft on 6/9/25.
//

import SwiftUI
import SwiftData

@main
struct atlasApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Place.self, TimeSlot.self])
    }
}
