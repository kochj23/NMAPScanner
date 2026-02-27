# HomeKit Adopter - Build Fix Instructions

**Issue:** "Unable to find module dependency: 'HomeKit'"
**Date:** 2025-11-21
**Status:** Requires Xcode GUI Configuration

---

## 🔴 Current Situation

The project is configured with:
- ✅ Development Team: **QRRCB8HB3W**
- ✅ Code Signing: **Automatic**
- ✅ Entitlements File: **HomeKitAdopter.entitlements** (configured)
- ✅ HomeKit Entitlement: **Enabled**
- ❌ **Provisioning Profile: Missing**

The build fails because HomeKit requires a provisioning profile, which must be created through Xcode's GUI or Apple Developer Portal.

---

## ✅ Quick Fix (Xcode is Already Open)

I've already opened the project in Xcode for you. Follow these steps:

### Step 1: Wait for Xcode to Load
- Xcode should now be open with HomeKitAdopter project
- Wait for Xcode to finish loading (progress bar at top)

### Step 2: Navigate to Signing & Capabilities
1. Click on **"HomeKitAdopter"** in the Project Navigator (left sidebar)
2. Select the **"HomeKitAdopter"** target (under TARGETS)
3. Click the **"Signing & Capabilities"** tab at the top

### Step 3: Fix Provisioning
You should see one of these scenarios:

#### Scenario A: "Repair" Button Visible
If you see a yellow warning with "Repair" button:
1. Click **"Repair"**
2. Xcode will automatically create provisioning profile
3. Wait for "Provisioning profile created" message
4. **Done!** Skip to Step 4

#### Scenario B: Register Mac
If you see "No devices registered" or "Register Mac":
1. Click **"Register Mac"** or **"Add Device"**
2. Xcode will register this Mac with your developer account
3. Wait for registration to complete
4. Xcode will then create provisioning profile automatically
5. **Done!** Skip to Step 4

#### Scenario C: Manual Device Addition
If registration doesn't work automatically:
1. Go to https://developer.apple.com/account/
2. Sign in with **[REDACTED]**
3. Go to **Certificates, Identifiers & Profiles**
4. Click **Devices**
5. Click **"+"** to add new device
6. Enter:
   - **Name:** Office M4-2 (or your Mac's name)
   - **UDID:** Run this command in Terminal:
     ```bash
     system_profiler SPHardwareDataType | grep "Hardware UUID"
     ```
7. Click **"Continue"** and **"Register"**
8. Go back to Xcode
9. Click **"Download Profile"** or **"Try Again"**
10. **Done!**

### Step 4: Verify Configuration
In Signing & Capabilities, you should now see:
- ✅ **Team:** Jordan Koch (QRRCB8HB3W)
- ✅ **Signing Certificate:** Apple Development
- ✅ **Provisioning Profile:** Xcode Managed Profile
- ✅ **Status:** No errors or warnings

---

## 🔨 Build the Project

Once provisioning is fixed:

### Option 1: Build in Xcode (Recommended)
1. In Xcode, press **⌘B** to build
2. Wait for build to complete
3. If successful, press **⌘R** to run
4. Grant HomeKit permission when prompted

### Option 2: Build from Command Line
```bash
cd /Volumes/Data/xcode/HomeKitAdopter
xcodebuild -sdk macosx -target HomeKitAdopter -configuration Debug \
  -arch arm64 ONLY_ACTIVE_ARCH=YES -allowProvisioningUpdates clean build
```

---

## 🐛 Troubleshooting

### Error: "Communication with Apple failed"
**Cause:** Network issue or Apple ID not signed in
**Fix:**
1. Xcode → Settings → Accounts
2. Verify your Apple ID is signed in
3. If not, click "+" and add your Apple ID
4. Try building again

### Error: "Your team has no devices"
**Cause:** This Mac is not registered with your developer account
**Fix:** Follow **Scenario B** or **Scenario C** above

### Error: "Provisioning profile expired"
**Cause:** Profile needs renewal
**Fix:**
1. In Signing & Capabilities
2. Click "Download Profile"
3. Or uncheck/recheck "Automatically manage signing"

### Build Succeeds but HomeKit Doesn't Work
**Cause:** Missing HomeKit permission
**Fix:**
1. Run the app
2. When prompted, click "Allow" for HomeKit access
3. If not prompted:
   - System Settings → Privacy & Security → HomeKit
   - Enable HomeKitAdopter

---

## 📋 What Was Already Configured

I've already configured these settings for you:

### Code Signing (project.pbxproj)
```
CODE_SIGN_STYLE = Automatic
DEVELOPMENT_TEAM = QRRCB8HB3W
CODE_SIGN_IDENTITY = Apple Development
CODE_SIGN_ENTITLEMENTS = HomeKitAdopter/HomeKitAdopter.entitlements
```

### Entitlements File (HomeKitAdopter.entitlements)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.homekit</key>
	<true/>
</dict>
</plist>
```

### Info.plist Permissions
```xml
<key>NSHomeKitUsageDescription</key>
<string>This app requires HomeKit access to discover...</string>

<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan HomeKit setup codes...</string>
```

---

## ✅ Success Criteria

You'll know the fix worked when:
1. ✅ No errors in Signing & Capabilities tab
2. ✅ Build succeeds (⌘B) with no errors
3. ✅ App runs (⌘R) and launches
4. ✅ App can import HomeKit framework
5. ✅ HomeKit permission prompt appears on first run

---

## 🎯 After Successful Build

Once the app builds and runs:

1. **Grant HomeKit Permission** when prompted
2. **Create a Home** using the "Homes" button
3. **Start Discovery** with the "Scan" button
4. **Pair Accessories** when discovered

See **QUICK-START-GUIDE.md** for detailed usage instructions.

---

## 💡 Why This Happened

HomeKit is a sensitive framework that requires:
1. **Valid Apple Developer Account** ✅ (You have: QRRCB8HB3W)
2. **Code Signing Certificate** ✅ (Found: Apple Development)
3. **Provisioning Profile** ❌ (Missing - needs Xcode GUI to create)
4. **Registered Device** ❌ (This Mac needs registration)

The command-line tools cannot automatically register devices or create provisioning profiles for HomeKit entitlements - this requires the Xcode GUI or manual configuration in Apple Developer Portal.

---

## 📞 Still Having Issues?

If problems persist:
1. Check Xcode console for specific error messages
2. Verify Apple ID is signed in (Xcode → Settings → Accounts)
3. Ensure internet connection is stable
4. Try restarting Xcode
5. Clean build folder (⌘⇧K) and rebuild

---

**Ready to Build!** 🚀

Once you complete the steps above, the project will build successfully and you can start using all 17 features of HomeKit Adopter!
