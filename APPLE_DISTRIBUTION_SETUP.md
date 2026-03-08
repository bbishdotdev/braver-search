# Apple Distribution Setup Guide

This guide matches the current GitHub Actions workflows in this repository.

Use it when you need to:
- refresh expired Apple certificates
- regenerate provisioning profiles
- rotate the App Store Connect API key
- update GitHub Actions secrets for TestFlight / App Store deployment

## Current CI Secret Names

These are the secrets the current deployment workflow reads:

- `APPLE_API_KEY_ID`
- `APPLE_API_KEY_ISSUER_ID`
- `APPLE_API_PRIVATE_KEY`
- `APPLE_TEAM_ID`
- `CERTIFICATE_PASSWORD`
- `DISTRIBUTION_CERTIFICATE_BASE64`
- `MAC_INSTALLER_CERTIFICATE_BASE64`
- `IOS_APP_PROFILE_BASE64`
- `IOS_EXT_PROFILE_BASE64`
- `MACOS_APP_PROFILE_BASE64`
- `MACOS_EXT_PROFILE_BASE64`

## 1. App Store Connect API Key

This key is used for upload/authentication with App Store Connect.

1. Go to App Store Connect -> Users and Access -> Keys.
2. If your existing CI key is still active, you can keep using it.
3. Otherwise create a new key.
4. Download the `.p8` file. Apple only lets you download it once.
5. Copy these values into GitHub Actions secrets:
   - `APPLE_API_KEY_ID`: the key ID
   - `APPLE_API_KEY_ISSUER_ID`: the issuer ID
   - `APPLE_API_PRIVATE_KEY`: the full contents of the `.p8` file, including BEGIN/END lines

## 2. Apple Distribution Certificate

This is the signing certificate used for App Store iOS and macOS app builds.

1. Open Keychain Access.
2. Go to Keychain Access -> Certificate Assistant -> Request a Certificate From a Certificate Authority.
3. Create a CSR and save it to disk.
4. Go to Apple Developer -> Certificates.
5. Create a new certificate of type `Apple Distribution`.
6. Upload the CSR.
7. Download and install the resulting certificate.
8. In Keychain Access, find it under `My Certificates`.
9. Export it as a `.p12` file with a password.
10. Put that password into GitHub as `CERTIFICATE_PASSWORD`.
11. Base64-encode the `.p12` and store it as `DISTRIBUTION_CERTIFICATE_BASE64`.

Command:

```bash
base64 -i distribution.p12 | pbcopy
```

## 3. Mac Installer Distribution Certificate

This is used for the macOS packaging/export path in CI.

1. Go to Apple Developer -> Certificates.
2. Create a new certificate of type `Mac Installer Distribution`.
3. Download and install it.
4. Export it from Keychain Access as a `.p12` file.
5. Use the same export password or a new one, but make sure `CERTIFICATE_PASSWORD` matches the `.p12` files you upload.
6. Base64-encode the `.p12` and store it as `MAC_INSTALLER_CERTIFICATE_BASE64`.

Command:

```bash
base64 -i mac_installer_distribution.p12 | pbcopy
```

## 4. Provisioning Profiles

Generate four distribution profiles using the current distribution certificate.

### iOS App Profile

1. Go to Apple Developer -> Profiles.
2. Create a new profile of type `App Store`.
3. Select bundle ID `xyz.bsquared.Braver-Search`.
4. Select the current `Apple Distribution` certificate.
5. Name it exactly:
   - `Braver Search iOS App Store`
6. Download it.
7. Base64-encode it into:
   - `IOS_APP_PROFILE_BASE64`

Command:

```bash
base64 -i Braver_Search_iOS_App_Store.mobileprovision | pbcopy
```

### iOS Extension Profile

1. Create a new profile of type `App Store`.
2. Select bundle ID `xyz.bsquared.Braver-Search.Extension`.
3. Select the current `Apple Distribution` certificate.
4. Name it exactly:
   - `Braver Search iOS Extension App Store`
5. Download it.
6. Base64-encode it into:
   - `IOS_EXT_PROFILE_BASE64`

Command:

```bash
base64 -i Braver_Search_iOS_Extension_App_Store.mobileprovision | pbcopy
```

### macOS App Profile

1. Create a new profile of type `Mac App Store`.
2. Select bundle ID `xyz.bsquared.Braver-Search`.
3. Select the current `Apple Distribution` certificate.
4. Name it exactly:
   - `Braver Search macOS App Store`
5. Download it.
6. Base64-encode it into:
   - `MACOS_APP_PROFILE_BASE64`

Command:

```bash
base64 -i Braver_Search_macOS_App_Store.provisionprofile | pbcopy
```

### macOS Extension Profile

1. Create a new profile of type `Mac App Store`.
2. Select bundle ID `xyz.bsquared.Braver-Search.Extension`.
3. Select the current `Apple Distribution` certificate.
4. Name it exactly:
   - `Braver Search macOS Extension App Store`
5. Download it.
6. Base64-encode it into:
   - `MACOS_EXT_PROFILE_BASE64`

Command:

```bash
base64 -i Braver_Search_macOS_Extension_App_Store.provisionprofile | pbcopy
```

## 5. Team ID

Set:

- `APPLE_TEAM_ID`

You can find it in:
- Apple Developer -> Membership
- or App Store Connect -> Users and Access

## 6. GitHub Actions Update Checklist

After rotating credentials, update these repository secrets in GitHub:

1. `APPLE_API_KEY_ID`
2. `APPLE_API_KEY_ISSUER_ID`
3. `APPLE_API_PRIVATE_KEY`
4. `APPLE_TEAM_ID`
5. `CERTIFICATE_PASSWORD`
6. `DISTRIBUTION_CERTIFICATE_BASE64`
7. `MAC_INSTALLER_CERTIFICATE_BASE64`
8. `IOS_APP_PROFILE_BASE64`
9. `IOS_EXT_PROFILE_BASE64`
10. `MACOS_APP_PROFILE_BASE64`
11. `MACOS_EXT_PROFILE_BASE64`

## 7. Common Failure Modes

- `No available devices matched the request`
  - CI is targeting a simulator/runtime that is not installed on the runner.
  - The current test workflow now selects an available simulator dynamically.

- `Profile doesn't include signing certificate`
  - Regenerate the provisioning profile using the current distribution certificate.

- `No signing certificate "Apple Distribution" found`
  - The uploaded `DISTRIBUTION_CERTIFICATE_BASE64` is wrong, expired, or the password in `CERTIFICATE_PASSWORD` does not match.

- `Authentication failed with App Store Connect`
  - Recheck `APPLE_API_KEY_ID`, `APPLE_API_KEY_ISSUER_ID`, and `APPLE_API_PRIVATE_KEY`.

- `Bundle identifier mismatch`
  - The bundle IDs in the provisioning profiles must match:
    - `xyz.bsquared.Braver-Search`
    - `xyz.bsquared.Braver-Search.Extension`

## 8. Recommended Order If Everything Is Old

If your CI setup is more than a year old, refresh in this order:

1. App Store Connect API key
2. Apple Distribution certificate
3. Mac Installer Distribution certificate
4. All four provisioning profiles
5. GitHub Actions secrets
6. Trigger the test workflow
7. Trigger the deployment workflow
