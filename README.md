# Melo Control

Unofficial Flutter app to control **QCY MeloBuds Pro** (and other QCY earbuds with matching vendor IDs) over BLE GATT on Android.

Not affiliated with QCY. Use at your own risk.

## Features

- Scan and connect to QCY earbuds (manufacturer ID `0x521c`)
- ANC modes, EQ presets, and per-band parametric EQ
- Gaming mode, LDAC, dual-device, sleep mode, in-ear detection
- Touch control mapping, auto power-off timer
- Volume, channel balance, find earbuds, rename, reset
- Auto-reconnect to last device

## Requirements

- Android phone with Bluetooth LE
- Flutter SDK 3.12+
- Android SDK (API level supported by `flutter_blue_plus`)

## Build

```bash
flutter pub get
flutter build apk --release
```

Release APK: `build/app/outputs/flutter-apk/app-release.apk`

Install:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Package

- **Application ID:** `com.httpkiwi.melocontrol`
- **Version:** 1.0.0

## Protocol & credits

The BLE command protocol, GATT layout, and product database used by this app are based on **[Quicky](https://github.com/hui1601/Quicky)** by [**hui1601**](https://github.com/hui1601).

Quicky reverse-engineered QCY earphone traffic and documents 40+ commands (ANC, EQ, key functions, battery, and more). Melo Control is a separate Flutter client that reimplements that protocol in Dart — it is **not** a fork of Quicky and does **not** include Quicky source code.

| Resource | Link |
|----------|------|
| Quicky repository | https://github.com/hui1601/Quicky |
| Protocol reference | [Quicky `docs/protocol.md`](https://github.com/hui1601/Quicky/blob/main/docs/protocol.md) |
| GATT services | [Quicky `docs/service.md`](https://github.com/hui1601/Quicky/blob/main/docs/service.md) |

Thank you to **hui1601** for publishing Quicky and the protocol documentation.

### Quicky licensing note

As of this writing, the [Quicky repository](https://github.com/hui1601/Quicky) does **not** include a `LICENSE` file. That means Quicky is **not** under an open-source license by default — standard copyright applies, and only the copyright holder grants permission to use their work.

This project documents its dependency on Quicky’s **public protocol write-up** for interoperability and gives attribution. It does **not** copy Quicky’s Go source into this repository. If you redistribute or build on Quicky itself, check with hui1601 or wait for an explicit license on that repo.

## License

**OpenQCY / Melo Control** (this repository): [MIT](LICENSE) — Copyright (c) 2026 httpkiwi.

Quicky is a separate project; see the note above.
