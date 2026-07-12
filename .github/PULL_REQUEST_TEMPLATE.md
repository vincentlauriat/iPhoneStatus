## Summary

<!-- What does this PR change, and why? -->

## Test plan

- [ ] `xcodegen generate` + `xcodebuild -scheme iPhoneStatus -configuration Debug test` passes locally
- [ ] Tested against a real connected iPhone (if the change touches device data fetching or parsing)
- [ ] `ARCHITECTURE.md` / `ARCHITECTURE_EN.md` updated together, if this changes a documented design decision
- [ ] No real device data (serial numbers, IMEI, etc.) introduced in test fixtures — synthetic values only
