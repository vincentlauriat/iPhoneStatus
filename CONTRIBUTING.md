# Contributing to iPhoneStatus

Thanks for considering a contribution. iPhoneStatus is a small, single-maintainer
menu bar utility — issues and small, focused PRs are welcome; please open an
issue before starting on anything large so we can align on approach first.

## Setup

Requirements:

- macOS 14.0 Sonoma or later
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the
  `.xcodeproj` is generated from `project.yml` and is **not** committed
- [libimobiledevice](https://libimobiledevice.org) (`brew install libimobiledevice`)
  — needed to exercise the app against a real device, not to build it

```bash
git clone https://github.com/vincentlauriat/iPhoneStatus.git
cd iPhoneStatus
xcodegen generate
open iPhoneStatus.xcodeproj
```

Re-run `xcodegen generate` any time you add/remove a source file, or after
pulling changes that touch `project.yml`.

## Building and testing

```bash
xcodegen generate
xcodebuild -scheme iPhoneStatus -configuration Debug build
xcodebuild -scheme iPhoneStatus -configuration Debug test
```

CI runs the same test command on every push and pull request (see
`.github/workflows/ci.yml`), with code signing disabled — no Apple Developer
account is needed to contribute.

## Code conventions

- Swift, `SWIFT_STRICT_CONCURRENCY: targeted` — avoid introducing data races;
  UI-facing types are `@MainActor`, background work goes through `DeviceMonitor`
  (an `actor`) or `Task.detached`.
  - `LibimobiledeviceService` shells out to the libimobiledevice CLI tools
  rather than binding their C libraries directly — see `ARCHITECTURE.md` /
  `ARCHITECTURE_EN.md` for the reasoning, and keep new device-data fetches
  consistent with that pattern (`Process`, drain stdout/stderr concurrently
  **before** `waitUntilExit()` — see the comment in `LibimobiledeviceService.run`
  for why the ordering matters).
- New optional device fields should follow the existing graceful-degradation
  pattern (`try?`, `nil` on failure) rather than surfacing an error — a field
  that isn't available on some device/iOS combination is normal, not exceptional.
- Personally-identifying fields (IMEI, ICCID, IMSI, phone number, serial
  numbers) are masked by default in the UI (`SensitiveDataMasking`). Don't
  introduce new sensitive fields displayed unmasked without going through the
  same masking helper.
- Doc-comments (`///`) on public types and functions are expected for anything
  a contributor would need to understand without reading the implementation.
- Add or update unit tests (`iPhoneStatusTests/`) for any change to plist
  parsing, state classification, or masking logic. **Never use real device
  data in test fixtures** — synthetic values only (see `MEMORY.md`'s note on
  the pre-publication data audit for why this matters).

## Pull requests

1. Fork, branch off `main`, keep the change focused.
2. Make sure `xcodebuild ... test` passes locally.
3. Update `ARCHITECTURE.md` **and** `ARCHITECTURE_EN.md` together if the change
   affects a documented design decision (they're meant to mirror each other).
4. Open the PR against `main` — CI must pass before merge.

## Reporting bugs / requesting features

Use the GitHub issue templates (`.github/ISSUE_TEMPLATE/`). For bugs, please
include your macOS version, iOS version of the connected device, and the
`libimobiledevice` version (`ideviceinfo -v` or `brew info libimobiledevice`).
