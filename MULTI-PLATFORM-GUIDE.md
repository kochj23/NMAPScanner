# HomeKit Adopter - Multi-Platform Guide

**Version:** 1.0.0
**Platforms:** macOS, iOS, tvOS
**Created by:** Jordan Koch & Claude Code
**Date:** 2025-11-21

## Platform Support

### Supported Platforms & Versions

| Platform | Minimum Version | Versions Supported |
|----------|----------------|-------------------|
| **macOS** | 13.0 (Ventura) | macOS 13, 14 (Sonoma), 15 (Sequoia) |
| **iOS** | 16.0 | iOS 16, 17, 18 |
| **tvOS** | 16.0 | tvOS 16, 17, 18 |

### Deployment Targets

```
MACOSX_DEPLOYMENT_TARGET = 13.0
IPHONEOS_DEPLOYMENT_TARGET = 16.0
TVOS_DEPLOYMENT_TARGET = 16.0
```

---

## Platform-Specific Features

### macOS
✅ **Fully Supported**
- Full window management
- Mouse/trackpad interaction
- Keyboard shortcuts
- Menu bar integration
- Camera QR scanning
- Multi-window support

### iOS
✅ **Fully Supported**
- Touch gestures
- Camera QR scanning
- Portrait/landscape orientation
- Dynamic Type support
- Accessibility features
- Compact and regular size classes

### tvOS
✅ **Supported with Adaptations**
- Siri Remote navigation
- Focus engine optimization
- Large, touch-friendly UI
- ❌ No camera (manual entry only)
- Card-based navigation
- Distance viewing optimization

---

## UI Adaptations by Platform

### Layout Differences

#### macOS
```swift
// Window sizing
.frame(minWidth: 800, minHeight: 600)
.windowStyle(.hiddenTitleBar)

// Fixed window size with resize capability
```

#### iOS
```swift
// Full screen with safe area insets
// Adaptive layout for different device sizes
// Support for split view and slide over
```

#### tvOS
```swift
// Focus-driven navigation
.focusable(true)
.buttonStyle(.card)

// Larger hit targets
// Distance-optimized text sizes
```

### Font Sizes

| Element | macOS | iOS | tvOS |
|---------|-------|-----|------|
| Header | 28pt | 34pt | 52pt |
| Body | 14pt | 16pt | 29pt |
| Caption | 11pt | 12pt | 23pt |

### Spacing & Padding

| Element | macOS | iOS | tvOS |
|---------|-------|-----|------|
| List Item Padding | 12pt | 16pt | 24pt |
| Card Corner Radius | 8pt | 12pt | 16pt |
| Icon Size | 60pt | 60pt | 80pt |

---

## Platform-Specific Code

### Conditional Compilation

```swift
#if os(macOS)
// macOS-specific code
import AppKit
typealias PlatformColor = NSColor

#elseif os(iOS)
// iOS-specific code
import UIKit
typealias PlatformColor = UIColor

#elseif os(tvOS)
// tvOS-specific code
import UIKit
typealias PlatformColor = UIColor
#endif
```

### Feature Availability

```swift
// Camera scanning
#if os(tvOS)
// tvOS doesn't have camera - show manual entry only
#else
// macOS and iOS support camera scanning
#endif

// Window management
#if os(macOS)
.windowStyle(.hiddenTitleBar)
#endif

// Focus engine
#if os(tvOS)
.focusable(true)
#endif
```

---

## Building for Each Platform

### Xcode Configuration

1. **Open in Xcode:**
   ```bash
   cd /Volumes/Data/xcode/HomeKitAdopter
   open HomeKitAdopter.xcodeproj
   ```

2. **Select Target:**
   - Choose "HomeKitAdopter" scheme
   - Select destination:
     - "My Mac" for macOS
     - iPhone/iPad simulator for iOS
     - Apple TV simulator for tvOS

3. **Enable Code Signing:**
   - Select target → Signing & Capabilities
   - Enable "Automatically manage signing"
   - Select your Team
   - Xcode will configure provisioning profiles

4. **Add HomeKit Capability:**
   - Click "+ Capability"
   - Add "HomeKit"
   - Entitlements added automatically

### Build Commands

#### macOS
```bash
xcodebuild \
  -project HomeKitAdopter.xcodeproj \
  -scheme HomeKitAdopter \
  -destination 'platform=macOS' \
  -configuration Release \
  build
```

#### iOS
```bash
xcodebuild \
  -project HomeKitAdopter.xcodeproj \
  -scheme HomeKitAdopter \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -configuration Release \
  build
```

#### tvOS
```bash
xcodebuild \
  -project HomeKitAdopter.xcodeproj \
  -scheme HomeKitAdopter \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -configuration Release \
  build
```

---

## Platform-Specific Limitations

### tvOS Limitations

1. **No Camera Support**
   - QR code scanning not available
   - Users must enter 8-digit code manually
   - UI automatically hides scan button

2. **No Keyboard**
   - Text entry via on-screen keyboard
   - Consider using digit-by-digit entry for codes

3. **Focus-Driven Navigation**
   - All interactive elements must be focusable
   - Requires card-style buttons
   - Test with Siri Remote

4. **Distance Viewing**
   - Larger fonts required
   - Higher contrast needed
   - Bigger hit targets (min 250pt)

### iOS Considerations

1. **Device Sizes**
   - Support iPhone SE (small) to iPhone 15 Pro Max (large)
   - iPad support with split view
   - Landscape and portrait orientations

2. **Camera Privacy**
   - Request camera permission
   - Handle denial gracefully
   - Provide manual entry fallback

3. **Background Behavior**
   - App may be suspended
   - HomeKit operations may timeout
   - Implement state restoration

### macOS Considerations

1. **Window Management**
   - Support resizing
   - Handle multiple windows
   - Remember window position

2. **Input Methods**
   - Keyboard shortcuts
   - Menu bar actions
   - Mouse/trackpad gestures

---

## Info.plist Requirements

### Common (All Platforms)
```xml
<key>NSHomeKitUsageDescription</key>
<string>HomeKit access is required to discover, pair, and manage HomeKit accessories.</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Local network access is required to discover HomeKit accessories on your network.</string>

<key>NSBonjourServices</key>
<array>
    <string>_hap._tcp</string>
    <string>_hap._udp</string>
    <string>_homekit._tcp</string>
</array>
```

### iOS & macOS Only
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan HomeKit setup codes (QR codes) from device labels.</string>
```

---

## Testing Checklist

### macOS Testing
- [ ] Window resizing works
- [ ] Menu bar items functional
- [ ] Keyboard navigation
- [ ] Camera scanning (if available)
- [ ] Multi-window support
- [ ] Dark mode support

### iOS Testing
- [ ] iPhone sizes (SE, standard, Plus/Max)
- [ ] iPad sizes (regular, Pro)
- [ ] Portrait orientation
- [ ] Landscape orientation
- [ ] Split view
- [ ] Slide over
- [ ] Camera scanning
- [ ] Dynamic Type
- [ ] VoiceOver
- [ ] Dark mode

### tvOS Testing
- [ ] Siri Remote navigation
- [ ] Focus engine behavior
- [ ] Button focus states
- [ ] Manual code entry
- [ ] Large text readability
- [ ] Distance viewing (10 feet)
- [ ] Card button styling
- [ ] No camera features shown

---

## Platform-Specific UI Guidelines

### macOS (Human Interface Guidelines)
- **Window Size:** Minimum 800x600
- **Click Targets:** Minimum 44x44 points
- **Typography:** SF Pro Text
- **Color:** Support light and dark mode
- **Spacing:** 8pt grid system

### iOS (Human Interface Guidelines)
- **Touch Targets:** Minimum 44x44 points
- **Typography:** SF Pro Text with Dynamic Type
- **Safe Area:** Respect safe area insets
- **Spacing:** 8pt grid system
- **Accessibility:** Support all accessibility features

### tvOS (Human Interface Guidelines)
- **Focus Targets:** Minimum 250x90 points
- **Typography:** SF Pro Display (larger sizes)
- **Viewing Distance:** Optimize for 10 feet
- **Focus Engine:** All interactive elements must be focusable
- **Spacing:** 50pt minimum between elements

---

## Code Organization

### Platform Files

```
HomeKitAdopter/
├── PlatformHelpers.swift          # Platform abstractions
├── HomeKitAdopterApp.swift        # Entry point (all platforms)
├── ContentView.swift               # Main view (adaptive)
├── Managers/
│   ├── HomeKitDiscoveryManager.swift  # Platform-agnostic
│   ├── HomeManagerWrapper.swift        # Platform-agnostic
│   └── LoggingManager.swift            # Platform-agnostic
└── Views/
    ├── AccessoryRowView.swift      # Adaptive layout
    ├── PairingView.swift           # Adaptive layout
    ├── AccessorySetupView.swift    # Adaptive layout
    └── SetupCodeScannerView.swift  # Platform-conditional
```

### Platform Detection Helpers

```swift
// In PlatformHelpers.swift
struct PlatformConstants {
    static var isTV: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }

    static var isMac: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }

    static var isiOS: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
}
```

---

## Deployment

### App Store Requirements

#### macOS App Store
- [ ] Code signed with Developer ID
- [ ] Notarized by Apple
- [ ] Hardened runtime enabled
- [ ] Sandbox entitlements configured
- [ ] Privacy manifest included

#### iOS App Store
- [ ] App Store icon (1024x1024)
- [ ] Launch screen
- [ ] App privacy details
- [ ] Screenshot for all device sizes
- [ ] App Store description

#### tvOS App Store
- [ ] App Store icon (1280x768)
- [ ] Top Shelf image
- [ ] tvOS-specific screenshots
- [ ] Focus on large display experience
- [ ] Siri Remote usage documented

---

## Troubleshooting

### Platform-Specific Issues

#### macOS
**Issue:** Window doesn't appear
**Solution:** Check window level and z-order

**Issue:** Camera not working
**Solution:** Grant camera permission in System Preferences

#### iOS
**Issue:** Layout issues on different devices
**Solution:** Use adaptive layout with size classes

**Issue:** App crashes on iPad
**Solution:** Test with both split view and full screen

#### tvOS
**Issue:** Can't navigate with remote
**Solution:** Ensure all buttons have `.focusable(true)`

**Issue:** Text too small
**Solution:** Use tvOS-specific font sizes (see table above)

---

## Performance Optimization

### Platform-Specific Optimizations

#### macOS
- Use efficient window management
- Minimize redraws
- Optimize for Retina displays

#### iOS
- Support low power mode
- Optimize for battery life
- Handle memory warnings

#### tvOS
- Optimize for focus changes
- Preload focus states
- Large image optimization

---

## Future Enhancements

### Planned Platform Features

- [ ] watchOS companion app
- [ ] iPad Pro Magic Keyboard support
- [ ] macOS Touch Bar support (if available)
- [ ] visionOS support (spatial computing)
- [ ] Handoff between devices
- [ ] iCloud sync for homes/settings

---

## Resources

### Apple Documentation
- [HomeKit Framework](https://developer.apple.com/documentation/homekit)
- [macOS HIG](https://developer.apple.com/design/human-interface-guidelines/macos)
- [iOS HIG](https://developer.apple.com/design/human-interface-guidelines/ios)
- [tvOS HIG](https://developer.apple.com/design/human-interface-guidelines/tvos)

### Sample Code
- [Building Apps for Multiple Platforms](https://developer.apple.com/documentation/xcode/supporting-multiple-platforms-in-your-app)
- [Conditional Compilation](https://docs.swift.org/swift-book/ReferenceManual/Statements.html#ID539)

---

## Support Matrix

| Feature | macOS | iOS | tvOS |
|---------|-------|-----|------|
| Network Discovery | ✅ | ✅ | ✅ |
| Manual Code Entry | ✅ | ✅ | ✅ |
| QR Code Scanning | ✅ | ✅ | ❌ |
| Home Management | ✅ | ✅ | ✅ |
| Room Management | ✅ | ✅ | ✅ |
| Accessory Pairing | ✅ | ✅ | ✅ |
| Multi-Window | ✅ | ❌ | ❌ |
| Split View | ❌ | ✅ | ❌ |
| Focus Engine | ❌ | ❌ | ✅ |

---

**Last Updated:** 2025-11-21
**Maintained by:** Jordan Koch & Claude Code

For questions or issues, refer to the main README.md or check the logs at:
- macOS/iOS: `~/Library/Application Support/HomeKitAdopter/Logs/`
- tvOS: Not accessible (use Xcode console)
