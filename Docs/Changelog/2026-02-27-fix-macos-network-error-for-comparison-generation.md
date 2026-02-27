# Changelog: Fix macOS Network Error During Comparison Generation

Date: 2026-02-27

## Summary

This changelog records the investigation and fix for a platform-specific issue where comparison generation worked on iPhone but failed on macOS with a network error in the same network environment.

## Root Cause

### 1. macOS sandbox entitlement missing outbound network permission

- The app had macOS sandbox enabled (`com.apple.security.app-sandbox = true`) but did not include outbound client networking entitlement.
- On macOS, this can block `URLSession` requests while iOS builds continue to work, which explained the cross-platform mismatch.

## Fixes Implemented

### 2. Added macOS network client entitlement

- Updated `WordsLearner/WordsLearner.entitlements` to include:
  - `com.apple.security.network.client = true`
- This allows outbound HTTPS requests from the sandboxed macOS app.

### 3. Improved AI HTTP error classification

- Updated `WordsLearner/Services/AIServiceClient.swift`:
  - Non-200 HTTP responses are now mapped more precisely:
    - `401/403` -> authentication error
    - `429` -> rate limit error
    - others -> API status error with status code
  - Added targeted `URLError` handling for real connection-layer failures.
- Result: avoids mislabeling all server/API failures as generic network errors.

## Project / Build Maintenance

### 4. Regenerated Tuist workspace and reopened in Xcode

- Regenerated project files with Tuist:
  - `/Users/zengdaqian/.local/share/mise/installs/tuist/4.141.0/bin/tuist generate --no-open`
- Opened workspace in Xcode:
  - `open -a Xcode /Users/zengdaqian/GitProject/WordsLearner/WordsLearner.xcworkspace`

## Verification Outcome

### 5. User validation

- User confirmed the issue was resolved after regeneration and reopening the workspace.
