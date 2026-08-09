# Runbook — installing the app on a phone

## Android

Working today on the current dev Mac. The Android SDK has everything the build
needs (`platform-tools`, `platforms/android-35` and `36`, `build-tools`,
accepted licences). `flutter doctor` complains that `cmdline-tools` is missing —
that only affects `sdkmanager`, not the build.

### Prerequisites on the phone

1. **Settings → About phone → tap "Build number" seven times** to unlock
   Developer options.
2. **Settings → Developer options → enable "USB debugging"**.
3. Connect the phone by USB and tap **Allow** on the "Allow USB debugging?"
   prompt. Choose *File transfer / Android Auto* mode if asked, not
   *Charging only* — charge-only mode hides the device from `adb`.

Confirm the Mac can see it:

```bash
make devices
```

The phone should appear in the `adb devices` list as `device` (not
`unauthorized` — that means the trust prompt was not accepted).

### The phone and the Mac must be on the same wifi

The app talks to the API on your Mac. `localhost` on the phone means the phone
itself, and `10.0.2.2` only works on an emulator, so the build bakes in the
Mac's LAN address. `make apk` and `make phone-run` detect it automatically.

Check what it detected:

```bash
make -n apk | grep -o 'http://[0-9.]*:8000'
```

If the Mac's IP changes (different wifi, DHCP lease), rebuild — the URL is
compiled in.

### Option A — run with hot reload (best for development)

```bash
make dev          # terminal 1: API, bound to 0.0.0.0 so the phone can reach it
make phone-run    # terminal 2: builds, installs and attaches
```

Hot reload with `r`, hot restart with `R`, quit with `q`. Logs stream to the
terminal.

### Option B — install a standalone APK

```bash
make apk           # builds with the Mac's LAN URL baked in
make apk-install   # adb install -r onto the connected phone
```

The app appears as **Aber Group**.

### Option C — no USB cable

Build with `make apk`, then transfer
`apps/app/build/app/outputs/flutter-apk/app-debug.apk` to the phone by AirDrop,
Google Drive, email or a USB stick, open it in the phone's Files app and tap it.
Android will ask permission to *install unknown apps* for whichever app is doing
the opening — grant it once.

### Confirming it works

The app opens on the **System status** screen. It should show:

* **Backend reachable** — `aber-api v0.1.0 · development`
* **API base URL** — the Mac's LAN address, e.g. `http://192.0.2.10:8000`

If it says *Backend unreachable*, work through these in order:

| Check | Command / action |
|---|---|
| Is the API running and bound to all interfaces? | `make dev` (it uses `--host 0.0.0.0`) |
| Can the Mac reach itself on the LAN IP? | `curl http://<LAN_IP>:8000/health` |
| Are both devices on the same wifi? | Compare the phone's wifi network with the Mac's |
| Is the Mac's firewall blocking it? | `/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate` — allow Python if enabled |
| Did the IP change since the build? | Rebuild with `make apk` |
| Guest/isolated wifi? | Many corporate and hotel networks block device-to-device traffic. Use a phone hotspot, with the Mac joined to it. |

### Why the APK is ~170 MB

Debug builds carry unstripped symbols and both architectures. A release build
(`flutter build apk --split-per-abi --release`) is roughly 20 MB per ABI, but
needs a signing key — that lands in M8 with app distribution.

### Android networking configuration

Two settings in the repo make this work, and both were needed:

* `INTERNET` and `ACCESS_NETWORK_STATE` are declared in
  `android/app/src/main/AndroidManifest.xml`. Flutter's template puts `INTERNET`
  in the *debug* manifest only, which produces a release APK that silently
  cannot reach the API.
* Android 9+ blocks cleartext HTTP. `android/app/src/debug/res/xml/network_security_config.xml`
  permits it for debug builds only; the main one keeps release **HTTPS-only**,
  which matters because this app carries passport scans and salary data.

---

## iOS

**Not possible on the current dev Mac.** It has only Command Line Tools, no full
Xcode and no CocoaPods, so `flutter build ios` cannot run.

To enable it:

```bash
# 1. Install Xcode from the App Store (large download, ~10-15 GB)
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept

# 2. CocoaPods
sudo gem install cocoapods     # or: brew install cocoapods

# 3. Verify
flutter doctor
```

Then, on the iPhone: **Settings → Privacy & Security → Developer Mode → on**
(iOS 16+), and trust the Mac when prompted.

Signing: open `apps/app/ios/Runner.xcworkspace` in Xcode, select the *Runner*
target → *Signing & Capabilities*, and set *Team* to a personal Apple ID. A free
Apple ID works but the app expires after **7 days** and the bundle identifier
must be globally unique — change `ae.abergroup.aber_app` if it is taken. A paid
Apple Developer Program membership ($99/year) gives one-year builds and
TestFlight distribution, which is what a real pilot rollout needs.

Note for iOS later: cleartext HTTP is blocked by App Transport Security, so a
debug `NSAppTransportSecurity` exception will be needed for local development,
mirroring the Android network security config.
