# AEGIS Capture for macOS (V46)

Desktop capture client for the **AEGIS V46** cloud brain.

## V46

- **No MT5 indicator template** — capture a plain price chart region.
- Server **pairs + rulebook registry**.
- Risk presets via `POST /api/account/risk_preset`.
- Client version `1.46.0`.

## Requirements

- macOS 14+ (ScreenCaptureKit)
- Screen Recording permission
- Portal Account ID + API key

## Build

```bash
./build.sh
```

See `Info.plist` and `AegisCapture.entitlements`.

## API

Same as Windows/Android: `/aegis/analyze`, `/api/registry/*`, heartbeat, risk preset.
