# Atlas

A live GPS navigation app for iOS that automatically routes to your daycare using the Valhalla routing engine.

## Features

- 🗺️ **Live GPS Tracking** - Continuous location monitoring with high accuracy
- 🚗 **Automatic Routing** - Real-time route calculation from your current location
- 📱 **No Manual Input** - Routes update automatically as you move
- 🔒 **Privacy Focused** - Location data stays on device with local routing

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd atlas
   ```

2. **Open in Xcode**
   ```bash
   open atlas.xcodeproj
   ```

3. **Build and run**
   - Select your target device or simulator
   - Press ⌘+R to build and run
   - Grant location permissions when prompted

## Requirements

- iOS 18.5+
- Xcode 16.4+
- Location permissions ("When In Use")

## How It Works

Atlas uses the Valhalla routing engine to calculate routes locally on your device. When you launch the app:

1. Location permission is requested
2. GPS tracking begins automatically
3. Routes are calculated to the configured daycare location
4. The route updates continuously as your location changes

## Configuration

The daycare location is currently hardcoded in `ContentView.swift`:
```swift
RoutingWaypoint(lat: 47.669553, lon: -122.363616, radius: 100)  // Daycare
```

To change the destination, modify these coordinates.

## Technical Details

- **Framework**: SwiftUI
- **Routing Engine**: Valhalla Mobile (local)
- **Location Services**: CoreLocation
- **Minimum iOS**: 18.5

For detailed technical documentation, see [CLAUDE.md](CLAUDE.md).

## Development

Build for simulator:
```bash
xcodebuild -project atlas.xcodeproj -scheme atlas -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## License

[Add your license here]