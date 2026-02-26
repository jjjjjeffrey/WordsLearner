# Changelog: Isolate macOS Debug Database from TestFlight via Bundle ID Split

Date: 2026-02-26

## Summary

This changelog records a macOS environment-isolation fix where Xcode Debug builds and the TestFlight app were sharing the same sandbox container (and SQLite database). The root cause was a shared bundle identifier across Debug and Release/TestFlight builds.

## Root Cause

### 1. Debug and TestFlight used the same app identity

- The app target used a single bundle identifier (`com.jeffrey.wordslearner`) for all configurations.
- On macOS, App Sandbox container storage is keyed by app identity (bundle ID + signing team).
- Because the identity matched, the Xcode-launched Debug build and the TestFlight-installed app resolved the same sandbox container and therefore the same default SQLite database location.

## Fix

### 2. Split bundle identifiers by build configuration

- Updated `Project.swift` to drive the app target bundle ID from `PRODUCT_BUNDLE_IDENTIFIER`.
- Set:
  - `Debug` -> `com.jeffrey.wordslearner.debug`
  - `Release` -> `com.jeffrey.wordslearner`
- This gives the Debug app a separate macOS sandbox container while keeping Release/TestFlight on the production identity.

## Project / Build Maintenance

### 3. Regenerated Tuist workspace

- Ran `tuist generate` after changing `Project.swift` so the local Xcode workspace reflects the configuration-specific bundle identifier settings.

## Notes

- This change isolates local sandbox-backed storage (including the default SQLite database path) between Debug and TestFlight on macOS.
- The project uses iCloud/CloudKit entitlements; if Debug signing/capabilities fail later, the new Debug bundle ID may need matching Apple Developer capability configuration.
