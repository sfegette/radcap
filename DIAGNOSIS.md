# Diagnosis: Microphone Permission Failures

## Core Issue: Bundle ID Mismatch
There is a significant mismatch between the Bundle Identifier defined in the project configuration and the one used in recovery scripts and code.

- **Defined in `project.yml`**: `com.brilliantmindworks.radcap`
- **Used in `CaptureManager.swift` (Reset Alerts)**: `com.sfegette.radcap`
- **Used in `scripts/release.sh` (Purge Logic)**: `com.sfegette.radcap`
- **Used in `CaptureManager.swift` (Logging Subsystem)**: `com.sfegette.radcap`

### Impact
1.  **Failed TCC Resets**: When the app or the `release.sh --purge` script attempts to fix permissions using `tccutil reset Microphone com.sfegette.radcap`, it targets a bundle ID that doesn't match the running app. The actual app's TCC entry (for `com.brilliantmindworks.radcap`) remains stale or corrupted.
2.  **Signature Mismatches**: Error `-11852` (`AVErrorApplicationIsNotAuthorizedToUseDevice`) occurs when TCC sees a valid entry but a different signing identity (e.g., switching from Debug to Developer ID). Without a working reset targeting the *correct* bundle ID, this error persists even after a reinstall.
3.  **Logging Blind Spot**: Logs sent to `com.sfegette.radcap` won't appear if you are filtering Console.app by the app's actual bundle ID.

## Secondary Observations
- **Race Condition**: `CaptureManager` calls `configureSession()` immediately after `requestAccess` completes. If the hardware isn't ready or `DiscoverySession` hasn't updated, the device might be missed.
- **Error Handling**: `handleMicInputError` only attempts recovery/retry for error `-11852`. Other potential errors (like `-11814` or `-50`) are ignored and just reported as errors.

## Recommended Fixes
1.  **Unify Bundle ID**: Change all references to `com.brilliantmindworks.radcap` (or the desired ID) across the entire project, especially in `release.sh` and `CaptureManager.swift`.
2.  **Update Reset Instructions**: Ensure the `sudo tccutil reset` command shown to users uses the correct bundle ID.
3.  **Verify Entitlements**: While present, ensure that the Hardened Runtime entitlements are correctly applied to the final signed binary.
