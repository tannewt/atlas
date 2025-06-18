import SwiftUI

struct SchematicMapView: View {
    let previewData = SchematicMapData.preview
    @Environment(\.sizeCategory) private var sizeCategory
    
    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            
            if isPortrait {
                // Portrait layout: VStack with cross streets and main road
                VStack() {
                    Spacer()
                    
                    // Cross streets above current position
                    ForEach(previewData.crossStreets.filter { $0.distanceAhead > 0 }, id: \.name) { street in
                        CrossStreetRowView(street: street)
                    }
                    
                    // Current position and main road
                    HStack {
                        VStack {
                            // Direction arrow
                            Image(systemName: "arrow.up")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            // Current position marker
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 12, height: 12)
                            }
                            
                            // Main road line (extends up and down)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: 8)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(previewData.currentRoad)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.leading, 8)
                        
                        Spacer()
                    }
                    
                    // Cross streets below current position
                    ForEach(previewData.crossStreets.filter { $0.distanceAhead <= 0 }, id: \.name) { street in
                        CrossStreetRowView(street: street)
                    }
                }
                .padding()
            } else {
                // Landscape layout: HStack with cross streets and main road
                HStack() {
                    // Cross streets to the left
                    ForEach(previewData.crossStreets.filter { $0.distanceAhead < 0 }, id: \.name) { street in
                        CrossStreetColumnView(street: street)
                    }
                    
                    // Current position and main road
                    VStack {
                        HStack {
                            // Direction arrow
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            // Current position marker
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 12, height: 12)
                            }
                            
                            // Main road line (extends left and right)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(height: 8)
                        }
                        
                        HStack {
                            Text(previewData.currentRoad)
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                    
                    // Cross streets to the right
                    ForEach(previewData.crossStreets.filter { $0.distanceAhead >= 0 }, id: \.name) { street in
                        CrossStreetColumnView(street: street)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CrossStreetRowView: View {
    let street: CrossStreet
    
    var body: some View {
        HStack {
            // Cross street line
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray)
                .frame(height: 4)
            
            // Cross street label
            Text(street.name)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.leading, 8)
            
            Spacer()
        }
    }
}

struct CrossStreetColumnView: View {
    let street: CrossStreet
    
    var body: some View {
        VStack {
            // Cross street line
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray)
                .frame(width: 4)
            
            Spacer()
            
            // Cross street label
            Text(street.name)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.top, 8)
        }
    }
}

struct CrossStreet {
    let name: String
    let distanceAhead: Double // in meters
}

struct SchematicMapData {
    let currentRoad: String
    let crossStreets: [CrossStreet]
    
    static let preview = SchematicMapData(
        currentRoad: "NE 45th Street",
        crossStreets: [
            CrossStreet(name: "15th Ave NE", distanceAhead: 10),
            CrossStreet(name: "Roosevelt Way NE", distanceAhead: 70),
            CrossStreet(name: "12th Ave NE", distanceAhead: 150)
        ]
    )
}

#Preview {
    SchematicMapView()
        .padding()
}
