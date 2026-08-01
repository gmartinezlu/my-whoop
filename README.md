# MyWHOOP Personal Reader

Native iOS 17+ SwiftUI project for personal interoperability with owned hardware. It does not include WHOOP proprietary protocol values, code, cloud APIs, telemetry, analytics, or assets.

## Structure

- `BLE/`: CoreBluetooth scan/connect/disconnect/notify flow with a single operation lock.
- `Protocol/`: typed BLE decoder stubs and placeholders for UUIDs, opcodes, offsets, and CRC details discovered from your own capture.
- `Compute/`: published, deterministic formulas for HRV, recovery/readiness, strain, sleep heuristics, stress, and workouts.
- `Storage/`: local SQLite via GRDB and an offline sync outbox.
- `Sync/`: HTTPS POST bridge to your configurable Vento webhook.
- `UI/`: SwiftUI Today and Settings screens.
- `App/`: iOS app entry point.

Each layer is a local Swift Package with its own `Package.swift`.

## Build Locally

On macOS with Xcode 15+:

```bash
xcodebuild \
  -project WhoopPersonal.xcodeproj \
  -scheme MyWhoop \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Run package tests:

```bash
for package in Protocol Compute Storage Sync BLE UI; do
  swift test --package-path "$package"
done
```

## GitHub Actions IPA

The workflow in `.github/workflows/build.yml` builds the app on `macos-latest` and uploads `MyWhoop-unsigned.ipa` as an artifact.

To install with AltStore or SideStore:

1. Open the GitHub Actions run.
2. Download the `MyWhoop-unsigned-ipa` artifact.
3. Extract the downloaded artifact ZIP.
4. Import the extracted `MyWhoop-unsigned.ipa` into AltStore or SideStore.
5. Sign it with your free Apple ID through the sideloading app.

GitHub Actions always wraps artifacts in a ZIP container. Do not import that outer ZIP into AltStore; import the `.ipa` file inside it. The `.ipa` is intentionally unsigned. A free Apple ID signs it during sideloading; no paid Apple Developer entitlements are required for this first version.

## Protocol Capture Workflow

Fill `BLE_CAPTURE_GUIDE.md` as you inspect your own Bluetooth capture. Then transfer observed UUIDs, opcodes, offsets, scale factors, and CRC rules into `Protocol/ProtocolConstants.swift` and `Protocol/BLEProtocolDecoder.swift`.

This Vento workspace mounts the existing top-level `docs/` directory as read-only, so the capture guide is kept at the project root instead of `docs/BLE_CAPTURE_GUIDE.md`.

Do not add guessed protocol values.

The current app includes a BLE discovery mode on the Today screen:

1. Tap `Scan`.
2. Select the nearby WHOOP peripheral when it appears.
3. Review discovered GATT services and characteristics.
4. Watch raw notify/indicate payloads captured as hex.
5. Copy confirmed findings into `BLE_CAPTURE_GUIDE.md`.

Recovery, strain, sleep, stress, and workout calculations intentionally use published formulas and heuristics. They are not WHOOP's proprietary algorithms.

## Vento Webhook

Open Settings in the app and set your Vento webhook URL. The only network operation implemented by this project is the POST performed by `Sync/VentoBridge.swift`.
