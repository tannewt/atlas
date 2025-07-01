//
//  ShareViewController.swift
//  Atlas Share Extension
//
//  Created by Scott Shawcroft on 7/1/25.
//

import UIKit
import SwiftUI
import SwiftData
import CoreLocation
import AtlasLibrary

class ShareViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up navigation
        title = "Add to Atlas"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add", style: .done, target: self, action: #selector(addToAtlas))
        
        // Process shared content immediately
        processSharedContent()
    }
    
    @objc func cancel() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    @objc func addToAtlas() {
        processSharedContent()
    }
    
    func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        // Handle text content
        if itemProvider.hasItemConformingToTypeIdentifier("public.plain-text") {
            itemProvider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (item, error) in
                DispatchQueue.main.async {
                    if let text = item as? String {
                        self?.handleSharedText(text)
                    } else if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                        self?.handleSharedText(text)
                    } else {
                        self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                    }
                }
            }
        }
        // Handle URL content
        else if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
            itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        self?.handleSharedURL(url)
                    } else {
                        self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                    }
                }
            }
        }
        else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    func handleSharedText(_ text: String) {
        // Parse the shared text for geo URLs
        if let parsedData = parseSharedText(text) {
            showPlaceEditView(latitude: parsedData.latitude, longitude: parsedData.longitude, name: parsedData.name)
        } else {
            showErrorView()
        }
    }
    
    func handleSharedURL(_ url: URL) {
        // Handle direct URL sharing
        if let decodedLocation = decodeGE0URL(url.absoluteString) {
            showPlaceEditView(latitude: decodedLocation.latitude, longitude: decodedLocation.longitude, name: decodedLocation.name)
        } else {
            showErrorView()
        }
    }
    
    func showPlaceEditView(latitude: Double, longitude: Double, name: String?) {
        // Create a SwiftUI place edit view using AtlasLibrary's PlaceEditView
        let placeEditView = SharePlaceEditView(
            latitude: latitude,
            longitude: longitude,
            name: name ?? "",
            onSave: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            },
            onCancel: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
        )
        
        let hostingController = UIHostingController(rootView: placeEditView)
        hostingController.modalPresentationStyle = .formSheet
        
        present(hostingController, animated: true)
    }
    
    func showErrorView() {
        let alert = UIAlertController(title: "No Location Found", message: "Could not extract location information from the shared content.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        })
        present(alert, animated: true)
    }
}

// MARK: - Parsing Functions (copied from main app)

struct SharedLocationData {
    let latitude: Double
    let longitude: Double
    let name: String?
}

struct DecodedLocation {
    let latitude: Double
    let longitude: Double
    let name: String?
}

func parseSharedText(_ text: String) -> SharedLocationData? {
    let urlPattern = #"https?://(comaps\.at|omaps\.app|ge0\.me)/[^\s]+"#
    
    guard let regex = try? NSRegularExpression(pattern: urlPattern, options: []),
          let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.count)) else {
        return nil
    }
    
    let urlRange = Range(match.range, in: text)!
    let urlString = String(text[urlRange])
    
    guard let decodedLocation = decodeGE0URL(urlString) else {
        return nil
    }
    
    let name = extractName(from: text, url: urlString)
    
    return SharedLocationData(
        latitude: decodedLocation.latitude,
        longitude: decodedLocation.longitude,
        name: name ?? decodedLocation.name
    )
}

func extractName(from text: String, url: String) -> String? {
    let lines = text.components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    
    let relevantLines = lines.filter { line in
        !line.hasPrefix("Check out") &&
        !line.contains("http") &&
        !line.contains("+1-") &&
        !line.contains("@") &&
        line.count > 2
    }
    
    return relevantLines.first
}

func decodeGE0URL(_ url: String) -> DecodedLocation? {
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
    
    let name = pathComponents.count > 1 ? pathComponents[1].replacingOccurrences(of: "_", with: " ") : nil
    
    return decodeGE0String(encodedPart, name: name)
}

func decodeGE0String(_ encoded: String, name: String?) -> DecodedLocation? {
    let base64Characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    
    guard encoded.count >= 1 else { return nil }
    
    var bytes: [UInt8] = []
    
    for char in encoded {
        guard let index = base64Characters.firstIndex(of: char) else {
            return nil
        }
        bytes.append(UInt8(base64Characters.distance(from: base64Characters.startIndex, to: index)))
    }
    
    guard bytes.count >= 1 else { return nil }
    
    let GE0_MAX_COORD_BITS = 31
    let GE0_MAX_POINT_BYTES = 10
    
    let latLonBytes = min(bytes.count - 1, GE0_MAX_POINT_BYTES)
    
    var lat: UInt64 = 0
    var lon: UInt64 = 0
    
    for i in 0..<latLonBytes {
        let shift = GE0_MAX_COORD_BITS - 3 - (i * 3)
        if shift < 0 { break }
        
        let a = bytes[i + 1]
        
        let lat1 = (((a >> 5) & 1) << 2) | (((a >> 3) & 1) << 1) | ((a >> 1) & 1)
        let lon1 = (((a >> 4) & 1) << 2) | (((a >> 2) & 1) << 1) | (a & 1)
        
        lat |= UInt64(lat1) << shift
        lon |= UInt64(lon1) << shift
    }
    
    let middleOfSquare = 1 << (3 * (GE0_MAX_POINT_BYTES - latLonBytes) - 1)
    lat += UInt64(middleOfSquare)
    lon += UInt64(middleOfSquare)
    
    let maxCoordValue = (1 << GE0_MAX_COORD_BITS) - 1
    let latitude = (Double(lat) / Double(maxCoordValue)) * 180.0 - 90.0
    let longitude = (Double(lon) / Double(1 << GE0_MAX_COORD_BITS)) * 360.0 - 180.0
    
    let roundedLat = round(latitude * 100000.0) / 100000.0
    let roundedLon = round(longitude * 100000.0) / 100000.0
    
    return DecodedLocation(
        latitude: roundedLat,
        longitude: roundedLon,
        name: name
    )
}

// MARK: - SwiftUI Views

struct SharePlaceEditView: View {
    let latitude: Double
    let longitude: Double
    let name: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        SharePlaceEditViewWrapper(
            latitude: latitude,
            longitude: longitude,
            name: name,
            onSave: onSave,
            onCancel: onCancel
        )
    }
}

struct SharePlaceEditViewWrapper: View {
    let latitude: Double
    let longitude: Double
    let name: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var modelContainer: ModelContainer?
    
    var body: some View {
        Group {
            if let container = modelContainer {
                SharePlaceEditViewWithContainer(
                    latitude: latitude,
                    longitude: longitude,
                    name: name,
                    onComplete: { success in
                        if success {
                            onSave()
                        } else {
                            onCancel()
                        }
                    }
                )
                .modelContainer(container)
            } else {
                Text("Loading...")
                    .onAppear {
                        setupModelContainer()
                    }
            }
        }
    }
    
    private func setupModelContainer() {
        do {
            let schema = Schema([Place.self, TimeSlot.self])
            let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.tech.chickadee.atlas")!
            let modelConfiguration = ModelConfiguration(schema: schema, url: appGroupURL.appendingPathComponent("Model.sqlite"))
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.modelContainer = container
        } catch {
            print("Failed to setup model container: \(error)")
            onCancel()
        }
    }
}

struct SharePlaceEditViewWithContainer: View {
    let latitude: Double
    let longitude: Double
    let name: String
    let onComplete: (Bool) -> Void
    
    @State private var editedName: String
    @State private var emoji: String = "📍"
    
    init(latitude: Double, longitude: Double, name: String, onComplete: @escaping (Bool) -> Void) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
        self.onComplete = onComplete
        self._editedName = State(initialValue: name)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Location") {
                    HStack {
                        Text("📍")
                            .font(.title2)
                        Text("\(latitude, specifier: "%.5f"), \(longitude, specifier: "%.5f")")
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                Section("Place Details") {
                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("📍", text: $emoji)
                            .multilineTextAlignment(.trailing)
                            .font(.title2)
                    }
                    
                    TextField("Name", text: $editedName)
                }
            }
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onComplete(false)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlaceToAtlas()
                    }
                    .disabled(editedName.isEmpty)
                }
            }
        }
    }
    
    private func savePlaceToAtlas() {
        do {
            let schema = Schema([Place.self, TimeSlot.self])
            let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.tech.chickadee.atlas")!
            let modelConfiguration = ModelConfiguration(schema: schema, url: appGroupURL.appendingPathComponent("Model.sqlite"))
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = ModelContext(container)
            
            let newPlace = Place(
                emoji: emoji,
                name: editedName,
                latitude: latitude,
                longitude: longitude,
                showPolicy: .nearby,
                nearbyDistance: 0.1
            )
            
            context.insert(newPlace)
            try context.save()
            
            onComplete(true)
        } catch {
            print("Failed to save place: \(error)")
            onComplete(false)
        }
    }
}

// MARK: - Place Models imported from shared location
