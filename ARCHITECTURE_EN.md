# Architecture — iPhoneStatus

## Overview

```
┌───────────────────────────────────────────────────────────┐
│                     macOS Menu Bar                         │
│   iphone icon, color-coded by state:                       │
│   green = connected · orange = needs trust ·                │
│   red = libimobiledevice missing · gray = no device         │
└─────────────────────────┬───────────────────────────────────┘
                          │ click
                          ▼
┌───────────────────────────────────────────────────────────┐
│           iPhoneStatus.app (AppKit + SwiftUI, macOS 14+)   │
│                                                              │
│  StatusMenuController (NSStatusItem + NSPopover, transient) │
│    └─ NSHostingController → PopoverContentView (SwiftUI)    │
│         4 states: binaries missing / no device /            │
│                    needs trust / connected                  │
│                                                              │
│  DeviceMonitor (actor, AsyncStream<DeviceConnectionState>)  │
│    ├─ presence poll:  idevice_id -l          every ~2s      │
│    └─ detail poll:    ideviceinfo (3 calls)  every ~10s,     │
│                        only while the popover is open        │
│                                                              │
│  LibimobiledeviceService (Sendable, Process wrapping)        │
│    ├─ idevice_id -l                                          │
│    ├─ ideviceinfo -u <udid> -x                                │
│    ├─ ideviceinfo -u <udid> -q com.apple.mobile.battery -x    │
│    └─ ideviceinfo -u <udid> -q com.apple.disk_usage -x        │
│                                                              │
│  libimobiledevice CLI (Homebrew: /opt/homebrew/bin)          │
│    └─ usbmuxd (built into macOS) ──USB/pairing── iPhone      │
└───────────────────────────────────────────────────────────┘
```

## Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| Language | Swift 5.9+ | Native macOS |
| UI shell | AppKit (`NSStatusItem`, `NSPopover`) | Explicit requirement — AppKit menu bar app, not SwiftUI `MenuBarExtra` |
| Popover content | SwiftUI, hosted via `NSHostingController` | Faster to iterate on the 4 UI states while keeping the AppKit shell |
| Device data source | libimobiledevice CLI (`idevice_id`, `ideviceinfo`) via `Process` | Mature, widely used open-source tool (Homebrew formula `libimobiledevice`, official/bottled); avoids maintaining a C interop layer for a solo-maintained MVP |
| Data format | plist XML (`-x` flag) decoded with `PropertyListDecoder` | Stable, typed output from `ideviceinfo` |
| Concurrency | Swift Concurrency (`actor`, `AsyncStream`), `SWIFT_STRICT_CONCURRENCY: targeted` | Matches the WifiManager/NetCheck convention (`ConnectivityMonitor` pattern) |
| Tests | XCTest (`iPhoneStatusTests`) | Pure functions (plist parsing, stderr classification) — no physical device required |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) | Matches all sibling projects |

## Why shell out instead of linking libimobiledevice's C library

Binding directly against `libimobiledevice`/`libplist`'s C headers would avoid text/plist parsing and give typed error codes, but requires a C module map, manual memory management around `idevice_t`/`lockdownd_client_t`, and ongoing maintenance as the upstream C API evolves. For a single-maintainer menu bar utility, shelling out to the CLI tools (`idevice_id`, `ideviceinfo`) and parsing their stable plist output is a better trade-off — the binaries are mature, the output format is documented and stable, and there is no C interop surface to maintain.

## Trust / pairing flow

`ideviceinfo` fails with a non-zero exit code until the "Trust This Computer" dialog has been accepted on the iPhone. `LibimobiledeviceService` captures stdout and stderr on **separate pipes** (mixing them would corrupt the plist parser), and `StderrClassifier` matches the stderr text case-insensitively against a small set of substrings:

- contains `"denied"` → `.denied` ("La confiance a été refusée")
- contains `"password"` → `.passwordProtected` ("iPhone verrouillé par un code")
- anything else (covers `"pending"`, `"trust"`, `"pair"`, `"lockdown"`, and any unrecognized message) → `.pendingConfirmation` ("En attente de confiance")

This generic fallback is deliberate: the exact wording of `lockdownd`'s error messages isn't guaranteed to be stable across libimobiledevice versions, so unknown messages degrade gracefully to the most common case instead of surfacing a raw error.

## Polling strategy

- **Presence** (`idevice_id -l`) is polled every ~2s regardless of whether the popover is open — it's a cheap local call to `usbmuxd` and doesn't require pairing.
- **Details** (`ideviceinfo` × 3 calls) are fetched once immediately when a new device is detected, then re-polled every ~10s **only while the popover is open** — there is no value in refreshing battery/storage data the user isn't looking at.

## Swift sources (`iPhoneStatus/Sources/`)

| File | Role |
|---|---|
| `iPhoneStatusApp.swift` | `@main` SwiftUI `App` entry point, wires `AppDelegate` via `@NSApplicationDelegateAdaptor` |
| `AppDelegate.swift` | Sets `.accessory` activation policy (no Dock icon), creates `StatusMenuController` |
| `StatusMenuController.swift` | `NSStatusItem` + `NSPopover`, color-coded icon, owns `DeviceMonitor` and `DeviceStatusViewModel` |
| `DeviceMonitor.swift` | `actor`; presence/detail polling loops; publishes `AsyncStream<DeviceConnectionState>` |
| `LibimobiledeviceService.swift` | Wraps `Process` calls to the CLI binaries; classifies failures |
| `LibimobiledeviceBinaryLocator.swift` | Locates `idevice_id`/`ideviceinfo` under `/opt/homebrew/bin` or `/usr/local/bin` |
| `iPhoneStatusInfo.swift` | `Decodable` plist models (`DeviceGlobalInfo`, `DeviceBatteryInfo`, `DeviceDiskUsageInfo`) + the combined `iPhoneStatusInfo` struct |
| `DeviceConnectionState.swift` | `DeviceConnectionState` / `TrustIssue` enums + `StderrClassifier` |
| `PopoverContentView.swift` | SwiftUI popover content, one branch per `DeviceConnectionState` case |

## Tests (`iPhoneStatusTests/`)

| File | Role |
|---|---|
| `PlistParsingTests.swift` | Decodes fixture plist XML into the `Decodable` models and checks `iPhoneStatusInfo.combining(...)` (including the `usedDiskCapacity` computation and default fallbacks) |
| `ErrorDetectionTests.swift` | Feeds sample `stderr` strings to `StderrClassifier.classify(_:)` and checks the resulting `TrustIssue` |

Both are pure-function tests — no `Process` execution, no physical device required.

## Out of scope for the MVP

Settings (refresh interval, Launch at Login), Sparkle auto-update, and a signed/notarized release pipeline were deliberately left out — see `TODOS.md`.
