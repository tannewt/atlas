import SwiftUI

struct SchematicMapView: View {
    let previewData = SchematicMapData.preview
    
    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            
            ZStack {
                // Background
                Color(.systemBackground)
                
                // Current road (main street - vertical in portrait, horizontal in landscape)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
                    .frame(
                        width: isPortrait ? 8 : geometry.size.width * 0.8,
                        height: isPortrait ? geometry.size.height * 0.8 : 8
                    )
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Current road label
                Text(previewData.currentRoad)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .position(
                        x: isPortrait ? geometry.size.width / 2 + 25 : 50,
                        y: isPortrait ? geometry.size.height - 30 : geometry.size.height / 2 + 25
                    )
                
                // Cross streets
                ForEach(Array(previewData.crossStreets.enumerated()), id: \.offset) { index, street in
                    let spacing: CGFloat = 80
                    let position = isPortrait ? 
                        geometry.size.height / 2 + CGFloat(index - 1) * spacing :
                        geometry.size.width / 2 + CGFloat(index - 1) * spacing
                    
                    // Cross street line (horizontal in portrait, vertical in landscape)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray)
                        .frame(
                            width: isPortrait ? 60 : 4,
                            height: isPortrait ? 4 : 60
                        )
                        .position(
                            x: isPortrait ? geometry.size.width / 2 : position,
                            y: isPortrait ? position : geometry.size.height / 2
                        )
                    
                    // Cross street label
                    Text(street.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .frame(width: 70)
                        .rotationEffect(.degrees(isPortrait ? 0 : -90))
                        .position(
                            x: isPortrait ? geometry.size.width / 2 + 50 : position,
                            y: isPortrait ? position : geometry.size.height / 2 + 50
                        )
                }
                
                // Direction indicator (arrow showing travel direction)
                Image(systemName: isPortrait ? "arrow.up" : "arrow.right")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .position(
                        x: geometry.size.width / 2,
                        y: isPortrait ? geometry.size.height / 2 - 120 : geometry.size.height / 2
                    )
                    .offset(
                        x: isPortrait ? 0 : 120,
                        y: isPortrait ? 0 : 0
                    )
                
                // Current position marker
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 12, height: 12)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    )
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
            CrossStreet(name: "15th Ave NE", distanceAhead: -100),
            CrossStreet(name: "Roosevelt Way NE", distanceAhead: 0),
            CrossStreet(name: "12th Ave NE", distanceAhead: 150)
        ]
    )
}

#Preview {
    SchematicMapView()
        .padding()
}