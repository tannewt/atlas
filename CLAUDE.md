# Atlas iOS Navigation App

## Project Overview
Atlas is an iOS navigation app that provides live GPS routing to a fixed daycare location using the Valhalla routing engine. The app automatically tracks the user's location and continuously updates the route without requiring manual input.

## Technical Stack
- **Platform**: iOS (SwiftUI)
- **Routing Engine**: Valhalla Mobile (local routing)
- **Location Services**: CoreLocation framework
- **Dependencies**:
  - ValhallaMobile (local package)
  - ValhallaModels
  - ValhallaConfigModels
  - Light-Swift-Untar
  - AnyCodable

## Key Features
- Automatic GPS location tracking with high accuracy
- Live route calculation from current location to daycare
- Continuous route updates on location changes
- Location permission handling ("when in use")
- No manual interaction required - fully automatic routing

## Project Structure
```
atlas/
├── atlas/
│   ├── ContentView.swift          # Main UI and LocationManager
│   ├── atlasApp.swift            # App entry point
│   ├── Info.plist                # Location usage description
│   ├── atlas.entitlements       # App sandbox entitlements
│   └── Assets.xcassets/          # App icons and assets
├── atlasTests/
├── atlasUITests/
└── atlas.xcodeproj/
```

## Build & Run
```bash
# Build for iPhone simulator
xcodebuild -project atlas.xcodeproj -scheme atlas -destination 'platform=iOS Simulator,name=iPhone 16' build

# Available simulators include iPhone 16, iPhone 16 Pro, iPad variants
```

## Configuration
- **Daycare Location**: Hardcoded to lat: 47.669553, lon: -122.363616
- **Location Accuracy**: kCLLocationAccuracyBest for highest precision
- **Routing Method**: Valhalla local routing with auto costing
- **Units**: Miles for distance measurements

## Location Services
The app requests "when in use" location permissions and includes the usage description:
"This app needs location access to provide turn-by-turn navigation to your daycare."

## Implementation Notes
- LocationManager class handles all CoreLocation interactions
- Routes automatically recalculate on every GPS location update
- UI shows current coordinates, route distance, time, and last update timestamp
- Error handling for location permission denial and routing failures
- No fallback to static locations - requires live GPS data

## Recent Changes
- Replaced static home coordinates with live GPS tracking
- Removed manual route button for automatic updates
- Added proper location permission flow
- Integrated continuous location monitoring

## Development Team
Team ID: 86XH5W9L9Q
Bundle ID: tech.chickadee.atlas