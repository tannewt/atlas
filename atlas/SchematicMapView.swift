import SwiftUI

struct SchematicMapView: View {
    let schematicData: SchematicMapData
    
    var body: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height > geometry.size.width
            
            if isPortrait {
                // Portrait layout: VStack with cross streets and main road
                VStack() {
                    Spacer()
                    
                    // Cross streets above current position
                    ForEach(schematicData.crossStreets.reversed().filter { $0.distanceAhead > 0 }, id: \.distanceAhead) { intersection in
                        CrossStreetIntersectionRowView(intersection: intersection)
                    }
                    
                    // Current position and main road
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
                        Text(schematicData.currentRoad)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                
                    // Cross streets below current position
                    ForEach(schematicData.crossStreets.filter { $0.distanceAhead <= 0 }, id: \.distanceAhead) { intersection in
                        CrossStreetIntersectionRowView(intersection: intersection)
                    }
                }
                .padding()
            } else {
                // Landscape layout: HStack with cross streets and main road
                HStack() {
                    // Cross streets to the left
                    ForEach(schematicData.crossStreets.filter { $0.distanceAhead < 0 }, id: \.distanceAhead) { intersection in
                        CrossStreetIntersectionColumnView(intersection: intersection)
                    }
                    
                    // Current position and main road
                    VStack {
                        Spacer()
                        VStack {
                            HStack {
                                // Main road line (extends left and right)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.blue)
                                    .frame(height: 8)
                                // Current position marker
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 12, height: 12)
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .frame(width: 12, height: 12)
                                }
                                // Direction arrow
                                Image(systemName: "arrow.right")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                
                            }
                            
                            HStack {
                                Text(schematicData.currentRoad)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                        Spacer()
                    }
                    
                    // Cross streets to the right
                    ForEach(schematicData.crossStreets.filter { $0.distanceAhead >= 0 }, id: \.distanceAhead) { intersection in
                        CrossStreetIntersectionColumnView(intersection: intersection)
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color(.systemGray6))
    }
}

struct CrossStreetIntersectionRowView: View {
    let intersection: CrossStreetIntersection
    
    var body: some View {
        HStack {
            // Left labels
            VStack(alignment: .trailing, spacing: 2) {
                ForEach(intersection.streets.filter { $0.heading < 0 }, id: \.names) { street in
                        Text(street.names?.joined(separator: ", ") ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .layoutPriority(1)
            
            // Street line
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray)
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray)
                    .frame(width: 4)
            }.frame(minWidth: 30)
            
            // Right labels
            VStack(alignment: .leading, spacing: 2) {
                ForEach(intersection.streets.filter { $0.heading >= 0 }, id: \.names) { street in
                        Text(street.names?.joined(separator: ", ") ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
    }
    
    private func headingArrowIcon(for heading: Int) -> String {
        switch heading {
        case -180..<(-135): return "arrow.down"
        case -135..<(-45): return "arrow.down.left"  
        case -45..<45: return "arrow.left"
        case 45..<135: return "arrow.up.left"
        case 135..<180: return "arrow.up"
        case -90: return "arrow.left"
        case 0: return "arrow.up"
        case 90: return "arrow.right"
        default:
            if heading > 0 && heading < 90 {
                return "arrow.up.right"
            } else if heading > -90 && heading < 0 {
                return "arrow.up.left"
            } else if heading > 90 && heading < 180 {
                return "arrow.up.right"
            } else {
                return "arrow.up"
            }
        }
    }
}

struct CrossStreetIntersectionColumnView: View {
    let intersection: CrossStreetIntersection
    
    var body: some View {
        VStack {
            // Top labels
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(intersection.streets.filter { $0.heading < 0 }, id: \.names) { street in
                        Text(street.names?.joined(separator: ", ") ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            
            // Street line
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray)
                    .frame(width: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray)
                    .frame(height: 4)
            }
            
            // Bottom labels
            HStack(alignment: .top, spacing: 2) {
                ForEach(intersection.streets.filter { $0.heading >= 0 }, id: \.names) { street in
                        Text(street.names?.joined(separator: ", ") ?? "")
                            .font(.caption)
                            .fontWeight(.medium)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

struct CrossStreet {
    let names: [String]?
    let heading: Int // degrees relative to main road (0 = straight ahead, -90 = left, 90 = right)
}

struct CrossStreetIntersection {
    let distanceAhead: Double // in meters
    let streets: [CrossStreet] // multiple streets can intersect at the same point
}

struct SchematicMapData {
    let currentRoad: String
    let crossStreets: [CrossStreetIntersection]
    
    static let preview = SchematicMapData(
        currentRoad: "NE 45th Street",
        crossStreets: [
            CrossStreetIntersection(
                distanceAhead: 10,
                streets: [
                    CrossStreet(names: ["15th Ave NE"], heading: -90)
                ]
            ),
            CrossStreetIntersection(
                distanceAhead: 70,
                streets: [
                    CrossStreet(names: ["Roosevelt Way NE"], heading: -75),
                    CrossStreet(names: ["Roosevelt Way NE (south)"], heading: 105)
                ]
            ),
            CrossStreetIntersection(
                distanceAhead: 150,
                streets: [
                    CrossStreet(names: ["12th Ave NE"], heading: 80),
                    CrossStreet(names: ["Campus Pkwy NE"], heading: -45)
                ]
            )
        ]
    )
}

#Preview {
    SchematicMapView(schematicData: SchematicMapData.preview)
        .padding()
}
