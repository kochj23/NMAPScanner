# HomeKit Adopter - Build Instructions

## Why the Build Fails

The error `import HomeKit` fails because:

1. **HomeKit requires entitlements** - Special permission from Apple
2. **Entitlements require code signing** - Valid Apple Developer certificate
3. **Code signing requires Apple Developer account** - Free or paid membership

This is an Apple security requirement - HomeKit controls physical devices in your home, so Apple requires all HomeKit apps to be properly signed and authorized.

---

## Solution 1: Use Xcode (Easiest)

### Step 1: Open in Xcode

```bash
cd /Volumes/Data/xcode/HomeKitAdopter
open HomeKitAdopter.xcodeproj
```

### Step 2: Configure Signing

1. In Xcode, click on **HomeKitAdopter** (blue icon) in the left sidebar
2. Select the **HomeKitAdopter** target (under TARGETS)
3. Click the **Signing & Capabilities** tab
4. Enable **"Automatically manage signing"** checkbox
5. Select your **Team** from the dropdown

**If you see "No Team":**
- Click **"Add Account..."** in the Team dropdown
- Sign in with your Apple ID
- Xcode will register you as a free developer

### Step 3: Add HomeKit Capability

1. Still in **Signing & Capabilities** tab
2. Click the **"+ Capability"** button (top left)
3. Search for **"HomeKit"**
4. Double-click to add it

### Step 4: Add PlatformHelpers.swift to Project

The file was created but needs to be added to Xcode:

1. In Xcode's left sidebar (Project Navigator)
2. Right-click on **HomeKitAdopter** folder (yellow folder icon)
3. Select **"Add Files to HomeKitAdopter..."**
4. Navigate to: `/Volumes/Data/xcode/HomeKitAdopter/HomeKitAdopter/`
5. Select **PlatformHelpers.swift**
6. Make sure **"Copy items if needed"** is UNCHECKED (already in folder)
7. Make sure **"Add to targets: HomeKitAdopter"** is CHECKED
8. Click **"Add"**

### Step 5: Build

Press **⌘B** or click **Product → Build**

---

## Solution 2: Command Line Build (After Xcode Setup)

Once you've configured signing in Xcode, you can build from command line:

### macOS
```bash
xcodebuild \
  -project /Volumes/Data/xcode/HomeKitAdopter/HomeKitAdopter.xcodeproj \
  -scheme HomeKitAdopter \
  -destination 'platform=macOS' \
  -configuration Debug \
  build
```

### iOS Simulator
```bash
xcodebuild \
  -project /Volumes/Data/xcode/HomeKitAdopter/HomeKitAdopter.xcodeproj \
  -scheme HomeKitAdopter \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -configuration Debug \
  build
```

### tvOS Simulator
```bash
xcodebuild \
  -project /Volumes/Data/xcode/HomeKitAdopter/HomeKitAdopter.xcodeproj \
  -scheme HomeKitAdopter \
  -destination 'platform=tvOS Simulator,name=Apple TV' \
  -configuration Debug \
  build
```

---

## Troubleshooting

### Error: "Signing for HomeKitAdopter requires a development team"

**Solution:** You need to add your Apple Developer account to Xcode:

1. Open Xcode
2. Go to **Xcode → Settings** (or **Preferences** on older versions)
3. Click **Accounts** tab
4. Click **+** button at bottom left
5. Select **Apple ID**
6. Sign in with your Apple ID
7. Close Settings and retry signing

### Error: "HomeKit capability requires a paid developer account"

**Temporary Solution:** You can use a free Apple Developer account for testing, but:
- Certificates expire every 7 days
- Need to re-sign every week
- Can't publish to App Store

**Permanent Solution:** Subscribe to Apple Developer Program ($99/year):
- Go to https://developer.apple.com/programs/
- Click **"Enroll"**
- Follow registration process

### Error: "Unable to find module dependency: 'HomeKit'"

This means code signing isn't configured. Follow Solution 1 above.

### Error: "No profiles for 'com.digitalnoise.homekitadopter' were found"

**Solution:**
1. Go to Signing & Capabilities
2. Change **Bundle Identifier** to something unique:
   - Current: `com.digitalnoise.homekitadopter`
   - Change to: `com.YOURNAME.homekitadopter` (replace YOURNAME)
3. Xcode will generate new provisioning profile

### Build succeeds but app crashes on launch

**Cause:** HomeKit entitlements not properly signed

**Solution:**
1. Check that HomeKit capability is added (Signing & Capabilities tab)
2. Clean build folder: **Product → Clean Build Folder** (⇧⌘K)
3. Rebuild: **Product → Build** (⌘B)

---

## Understanding the Error

When you see:
```
import HomeKit
^
error: Unable to find module dependency: 'HomeKit'
```

This doesn't mean HomeKit framework is missing. It means:
- The compiler can't access HomeKit because entitlements aren't signed
- Apple blocks access to HomeKit APIs without proper authorization
- Code signing with HomeKit entitlement grants access

Think of it like a secure building:
- 🏢 HomeKit = Secure building
- 🔑 Entitlement = Access card
- ✍️ Code signing = Security guard validates your card
- 👤 Apple Developer Account = Building administration that issues cards

Without the signed entitlement, the compiler won't even let you "see" the HomeKit framework.

---

## Alternative: Test Without HomeKit (Not Recommended)

If you just want to test the app structure without HomeKit functionality, you could:

1. Comment out all HomeKit imports
2. Create mock HomeKit classes
3. Test UI only

But this defeats the purpose of the app! HomeKit Adopter is specifically for pairing HomeKit accessories.

---

## Verification Steps

After configuring signing, verify:

1. **Check Signing:**
   - Go to Signing & Capabilities
   - Should show your Team name
   - Should show "Signing Certificate: Apple Development"
   - Should show provisioning profile name

2. **Check Entitlements:**
   - HomeKit should be in capabilities list
   - File `HomeKitAdopter.entitlements` should contain:
   ```xml
   <key>com.apple.developer.homekit</key>
   <true/>
   ```

3. **Test Build:**
   - Press ⌘B
   - Should build without errors
   - Check build log for "Code Sign" success

---

## Next Steps After Successful Build

1. **Run on Simulator:**
   - Select destination (Mac, iPhone, Apple TV)
   - Press ⌘R to run
   - Grant permissions when prompted

2. **Test on Real Device:**
   - Connect device via USB
   - Select device as destination
   - Trust device if prompted
   - Run app (⌘R)

3. **Test HomeKit Discovery:**
   - Ensure device/simulator and HomeKit accessories on same network
   - Grant HomeKit permissions
   - Click "Scan for Devices"
   - Should discover HomeKit accessories

---

## Free vs Paid Developer Account

### Free Account (Apple ID)
✅ Can build and test on your own devices
✅ Can use HomeKit (with limitations)
✅ Good for personal use
❌ Certificates expire every 7 days
❌ Can't publish to App Store
❌ Limited to 3 devices
❌ No TestFlight

### Paid Account ($99/year)
✅ All features of free account
✅ Certificates valid for 1 year
✅ Publish to App Store
✅ TestFlight for beta testing
✅ Unlimited devices
✅ App Store Connect access
✅ Advanced capabilities

---

## Still Having Issues?

### Check Xcode Version
```bash
xcodebuild -version
```
Should be **Xcode 15.0 or later**

### Check for Multiple Xcode Installations
```bash
xcode-select -p
```
Should point to: `/Applications/Xcode.app/Contents/Developer`

If not, set it:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Clean Everything
```bash
cd /Volumes/Data/xcode/HomeKitAdopter
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild clean
```

Then rebuild in Xcode.

---

## Success Checklist

- [ ] Xcode is installed (15.0+)
- [ ] Apple Developer account added to Xcode
- [ ] Team selected in Signing & Capabilities
- [ ] HomeKit capability added
- [ ] PlatformHelpers.swift added to project
- [ ] Build succeeds (⌘B)
- [ ] App runs on simulator/device (⌘R)
- [ ] HomeKit permissions granted
- [ ] Can scan for accessories

---

## Getting Help

If you're still stuck:

1. **Check build log:**
   - View → Navigators → Show Report Navigator (⌘9)
   - Click latest build
   - Look for specific error messages

2. **Screenshot the error:**
   - Take screenshot of entire Xcode window
   - Include signing settings
   - Include error message

3. **System info:**
   ```bash
   sw_vers  # macOS version
   xcodebuild -version  # Xcode version
   ```

4. **Project info:**
   ```bash
   cd /Volumes/Data/xcode/HomeKitAdopter
   xcodebuild -list
   ```

---

**Remember:** The build error is expected without proper signing. This is Apple's security by design for HomeKit apps. Once signing is configured, everything will work!

**Last Updated:** 2025-11-21
