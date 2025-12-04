# Running HomeKitAdopter on Office Apple TV

## Method 1: Using CMD-R in Xcode (Recommended)

1. **Open the project in Xcode:**
   ```bash
   open /Volumes/Data/xcode/HomeKitAdopter/HomeKitAdopter.xcodeproj
   ```

2. **Select the Office Apple TV as destination:**
   - At the top of Xcode, next to the scheme dropdown (where it says "HomeKitAdopter")
   - Click on the destination dropdown (might say "My Mac" or "Apple TV")
   - Select **"Office"** from the list of available devices

3. **Run with CMD-R:**
   - Press `⌘R` (CMD-R) to build and run
   - The app will install and launch on your Office Apple TV

**Note:** Xcode will remember this destination, so subsequent CMD-R presses will use the Office Apple TV.

---

## Method 2: Using the Shell Script

I've created a convenience script that always runs on the Office Apple TV:

```bash
cd /Volumes/Data/xcode/HomeKitAdopter
./run-on-office-tv.sh
```

This script:
- Builds the project
- Installs it on the Office Apple TV
- Provides clear success/failure messages

---

## Method 3: Using xcodebuild Command

You can also run directly with xcodebuild:

```bash
cd /Volumes/Data/xcode/HomeKitAdopter

# Build and run on Office Apple TV
xcodebuild \
  -project HomeKitAdopter.xcodeproj \
  -scheme HomeKitAdopter \
  -destination 'platform=tvOS,name=Office' \
  -allowProvisioningUpdates \
  build
```

---

## Troubleshooting

### Office Apple TV not showing up?

**Check device connection:**
```bash
xcrun devicectl list devices | grep -i office
```

You should see:
```
Office               Office-10.coredevice.local          915604CB-97FF-5F2E-9AE6-15AEB8852719   available (paired)   Apple TV 4K (3rd generation)
```

### Device not paired?

1. Open Xcode
2. Go to **Window → Devices and Simulators** (Shift-CMD-2)
3. Select your Office Apple TV
4. Click "Connect" or "Trust" if prompted
5. Enter the pairing code shown on your TV

### Still not working?

Make sure:
- Your Mac and Apple TV are on the same network
- The Apple TV is turned on
- The Apple TV is not in sleep mode
- You have accepted the developer profile on the Apple TV:
  - Settings → General → Device Management → Trust your developer certificate

---

## Your Office Apple TV Details

- **Name:** Office
- **Model:** Apple TV 4K (3rd generation)
- **Device ID:** 915604CB-97FF-5F2E-9AE6-15AEB8852719
- **Host:** Office-10.coredevice.local
- **Status:** Paired and Available

---

## Quick Reference

### Available Devices:
You have 3 Apple TVs connected:
1. **Office** (Office-10.coredevice.local) ← **Default for this project**
2. Living Room (Living-Room.coredevice.local)
3. Master Bedroom (3) (Master-Bedroom-3.coredevice.local)

### Change Default Device:
To change which Apple TV is used by default:
1. Open Xcode
2. Select the desired device from the destination dropdown
3. Build and run (CMD-R)
4. Xcode will remember your choice

---

## Building from Command Line

### Build only:
```bash
xcodebuild -project HomeKitAdopter.xcodeproj -scheme HomeKitAdopter -destination 'platform=tvOS,name=Office' build
```

### Clean and build:
```bash
xcodebuild -project HomeKitAdopter.xcodeproj -scheme HomeKitAdopter -destination 'platform=tvOS,name=Office' clean build
```

### Archive (for distribution):
```bash
xcodebuild -project HomeKitAdopter.xcodeproj -scheme HomeKitAdopter -destination 'generic/platform=tvOS' archive -archivePath ./build/HomeKitAdopter.xcarchive
```

---

**Version:** 2.2
**Last Updated:** November 22, 2025
**Authors:** Jordan Koch
