# Fix HomeKit Build Error - DO THIS NOW

**Error:** "No such module 'HomeKit'"
**Cause:** Provisioning profile not properly configured for HomeKit entitlements
**Fix Time:** 30 seconds in Xcode

---

## THE FIX (Do this right now in Xcode):

### Step 1: Open Signing & Capabilities
1. Xcode should already be open with HomeKitAdopter project
2. In the left sidebar (Project Navigator), click the **blue "HomeKitAdopter" icon** at the very top
3. In the main editor area, under **TARGETS**, click **"HomeKitAdopter"**
4. At the top of the editor, click the **"Signing & Capabilities"** tab

### Step 2: Fix the Provisioning Profile

You will see ONE of these:

#### Option A: Yellow/Red Error with "Repair" or "Try Again" Button
```
⚠️ Provisioning profile error...
[Repair Button] or [Try Again Button]
```
**DO THIS:** Click the **"Repair"** or **"Try Again"** button

#### Option B: "Register Device" Button
```
❌ Your team has no devices from which to generate a provisioning profile
[Register Device Button]
```
**DO THIS:** Click **"Register Device"** button

#### Option C: Everything Looks Good
```
✅ Signing Certificate: Apple Development
✅ Provisioning Profile: Xcode Managed Profile
✅ Team: Jordan Koch (QRRCB8HB3W)
```
**DO THIS:** The provisioning is already correct. The build should work.

### Step 3: Rebuild

After clicking the button in Step 2:

1. Wait 5-10 seconds for Xcode to update the profile
2. Press **⌘⇧K** (Command+Shift+K) to clean
3. Press **⌘R** (Command+R) to run

The build should now succeed.

---

## Why This Happens:

HomeKit is a **privileged framework** that requires:
1. Valid Apple Developer account ✅ (you have this)
2. Registered device ✅ (Mac is registered)
3. **Provisioning profile with HomeKit entitlement** ❌ (needs manual click in Xcode)

The command-line tools **cannot** create HomeKit provisioning profiles automatically. You MUST click the button in Xcode's GUI.

---

## What Should Happen After You Click:

Xcode will:
1. Contact Apple's servers
2. Create a provisioning profile with HomeKit entitlement
3. Download it to your Mac
4. Configure the project to use it

This takes 5-10 seconds.

---

## If It Still Fails:

### Check Your Apple ID in Xcode:

1. Xcode menu → **Settings** (or Preferences)
2. Click **"Accounts"** tab
3. Verify you see: **[REDACTED]**
4. If not there, click **"+"** and sign in
5. Close Settings
6. Go back to Signing & Capabilities and try Step 2 again

---

## After It Works:

Once the build succeeds, the app will launch and you'll see:
1. **HomeKit permission dialog** - Click "Allow"
2. The main HomeKit Adopter interface
3. You can start discovering accessories

---

## Screenshot Guide:

### What You're Looking For in "Signing & Capabilities":

```
┌─────────────────────────────────────────────────┐
│ Signing & Capabilities Tab                      │
├─────────────────────────────────────────────────┤
│                                                 │
│ Signing                                         │
│ ☑ Automatically manage signing                 │
│                                                 │
│ Team: Jordan Koch (QRRCB8HB3W)                 │
│                                                 │
│ Bundle Identifier: com.digitalnoise.homekit... │
│                                                 │
│ ⚠️ ERROR MESSAGE HERE (if any)                  │
│ [Repair Button] <-- CLICK THIS                 │
│                                                 │
│ Signing Certificate: Apple Development          │
│ Provisioning Profile: Xcode Managed Profile    │
│                                                 │
│ + Capability                                    │
│                                                 │
│ HomeKit                                         │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

## Common Mistakes:

❌ **DON'T** try to fix this from command line - it won't work
❌ **DON'T** skip clicking the Repair/Register button - it's required
❌ **DON'T** change the bundle ID or team - they're correct

✅ **DO** click the button Xcode shows you
✅ **DO** wait for Xcode to finish (5-10 seconds)
✅ **DO** clean and rebuild after

---

**Once you do this, the "No such module 'HomeKit'" error will be gone forever.**

This is a one-time setup. After this, all future builds will work.
