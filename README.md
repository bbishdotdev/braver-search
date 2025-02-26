# Braver Search

A Safari extension that automatically redirects searches to Brave Search, providing a more private search experience.

> **Disclaimer**: Braver Search is an independent Safari extension and is not affiliated with, endorsed by, or connected to Brave Software Inc. This is a third-party tool created to enhance the user experience of [Brave Search](https://search.brave.com) within Safari, which is a trademark of Brave Software Inc.

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-yellow.svg?style=flat&logo=buy-me-a-coffee)](https://www.buymeacoffee.com/brendenbishop)
[![App Store](https://img.shields.io/badge/Download%20on%20the-App%20Store-blue.svg?style=flat&logo=app-store&logoColor=white)](https://apps.apple.com/us/app/braver-search/id6740840706)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-lightgrey.svg?style=flat)
![License](https://img.shields.io/badge/license-MIT%20with%20Commons%20Clause-green.svg?style=flat)

## About Brave Search

This extension redirects your searches to [Brave Search](https://search.brave.com), a privacy-respecting search engine created by [Brave Software Inc](https://brave.com). Brave Search offers:
- Independent search results
- Privacy-first approach
- No tracking or profiling
- Transparent ranking
- Community-powered features

Learn more about Brave Search:
- [About Brave Search](https://brave.com/search/)
- [Brave Search Blog](https://brave.com/search/blog/)
- [Brave Search Help Center](https://support.brave.com/search)

## Support the Project
- [![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-yellow.svg?style=flat&logo=buy-me-a-coffee)](https://www.buymeacoffee.com/brendenbishop)
- [![App Store](https://img.shields.io/badge/Download%20on%20the-App%20Store-blue.svg?style=flat&logo=app-store&logoColor=white)](https://apps.apple.com/us/app/braver-search/id6740840706)
- ⭐ Star this repository
- 🐛 Report bugs and contribute fixes

## Project Structure

```
Braver Search/
├── iOS (App)/               # iOS host app
├── iOS (Extension)/         # iOS extension-specific code
├── macOS (App)/            # macOS host app
├── macOS (Extension)/      # macOS extension-specific code
├── Shared (App)/           # Shared app code
└── Shared (Extension)/     # Shared extension code and resources
    ├── Resources/
    │   ├── popup.html      # Extension popup UI
    │   ├── popup.css       # Popup styling
    │   ├── popup.js        # Popup functionality
    │   └── background.js   # Core extension functionality
    └── SafariWebExtensionHandler.swift  # Native bridge
```

## Components

### Extension Core (`background.js`)
- Monitors web navigation events
- Intercepts search queries from Safari's default search engine
- Redirects to Brave Search when enabled
- Uses `browser.storage.local` for state management

### Popup Interface
- **HTML (`popup.html`)**: Simple UI with toggle switch and status indicator
- **CSS (`popup.css`)**: Modern styling with system-native appearance
- **JavaScript (`popup.js`)**: Handles user interactions and state management

### Native Integration
- **SafariWebExtensionHandler**: Manages extension state and Safari integration
- Supports both iOS and macOS platforms
- Uses UserDefaults for persistent storage

## How It Works

1. **State Management**
   - Extension state (enabled/disabled) stored in `browser.storage.local`
   - Persists across browser sessions
   - Syncs between popup and background script

2. **Search Redirection**
   - Background script monitors navigation events
   - Detects search queries in URLs
   - When enabled, redirects to Brave Search with the same query

3. **User Interface**
   - Toggle switch to enable/disable redirection
   - Visual indicators for current state
   - Instant feedback on state changes

## Development

### Contributing
We welcome contributions! Here's how you can help:
- Fork the repository
- Create a feature branch
- Submit pull requests
- Report bugs via issues
- Improve documentation
- Share feedback and suggestions

### Prerequisites
- Xcode 15+
- iOS 17.0+ / macOS 14.0+
- Safari 17.0+

### Building
1. Clone the repository
2. Open `Braver Search.xcodeproj` in Xcode
3. Select target platform (iOS/macOS)
4. Build and run

## Deployment

### Prerequisites
- Apple Developer Program membership
- App Store Connect API key
- Xcode 15.1+ (recommended)
- GitHub Actions for CI/CD

### Certificates and Profiles Setup
1. **Distribution Certificates**
   - iOS/macOS Distribution Certificate
   - Mac Installer Distribution Certificate (for macOS pkg)
   - Store both certificates securely as base64 in GitHub Secrets:
     - `DISTRIBUTION_CERTIFICATE_BASE64`
     - `MAC_INSTALLER_CERTIFICATE_BASE64`
     - `CERTIFICATE_PASSWORD`

2. **Provisioning Profiles**
   - iOS App Store Profile (main app)
   - iOS App Store Profile (extension)
   - macOS App Store Profile (main app)
   - macOS App Store Profile (extension)
   - Store all profiles as base64 in GitHub Secrets:
     - `IOS_APP_PROFILE_BASE64`
     - `IOS_EXT_PROFILE_BASE64`
     - `MACOS_APP_PROFILE_BASE64`
     - `MACOS_EXT_PROFILE_BASE64`

3. **App Store Connect API**
   - Create API Key in App Store Connect
   - Store credentials in GitHub Secrets:
     - `APPLE_API_KEY_ID`
     - `APPLE_API_KEY_ISSUER_ID`
     - `APPLE_API_PRIVATE_KEY`
     - `APPLE_TEAM_ID`

### Xcode Project Setup
1. **Code Signing**
   - Set manual code signing for all targets
   - Match provisioning profile names with workflow:
     - iOS App: "Braver Search iOS App Store"
     - iOS Extension: "Braver Search iOS Extension App Store"
     - macOS App: "Braver Search macOS App Store"
     - macOS Extension: "Braver Search macOS Extension App Store"

2. **Build Settings**
   - Set `DEVELOPMENT_TEAM` to match your team ID
   - Enable App Groups capability if needed
   - Set proper bundle identifiers
   - Configure proper deployment targets

### App Icon Requirements
- Provide all required sizes for iOS and macOS
- Ensure icons have no alpha channel or transparency
- Use solid background color or gradient
- Let the system handle icon corner radius

### GitHub Actions Workflow
The repository includes a GitHub Actions workflow for automated deployment:
- Triggers on push to main or manual dispatch
- Builds both iOS and macOS targets
- Signs with provided certificates
- Creates proper installers
- Uploads to TestFlight and App Store
- Handles cleanup of sensitive data

To use the workflow:
1. Set up all required secrets in GitHub
2. Ensure Xcode project settings match workflow expectations
3. Test the workflow using manual dispatch
4. Monitor build and upload progress in Actions tab

### Troubleshooting
Common issues and solutions:
- **Code Signing Errors**: Verify certificate and profile matches
- **Build Errors**: Check Xcode version compatibility
- **Upload Errors**: Verify App Store Connect API credentials
- **Icon Validation**: Ensure no transparency in app icons
- **Extension Issues**: Verify manifest.json configuration

## License

This project is licensed under the MIT License with Commons Clause.

### Personal Use and Contributions (MIT License)
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to:
- Use the software for personal, non-commercial purposes
- Modify the software for personal use
- Contribute improvements back to the main repository
- Fork the repository for personal projects

### Commons Clause Restriction
The Commons Clause restricts you from:
- Selling the software or modifications of it
- Using the software in commercial products without authorization
- Redistributing the software through commercial channels

### App Store Distribution
- Official distribution through the App Store is exclusively by Brenden Bishop
- One-time purchase price: $4.99
- Family Sharing enabled
- Updates included
- App Store terms and EULA apply

### Privacy and Data Collection
- No personal information collected
- Search queries sent directly to Brave Search
- Settings stored locally
- No analytics or tracking

## Contributing

We love contributions! Here's how:

### Ways to Contribute
- Submit bug reports
- Propose new features
- Improve documentation
- Submit pull requests
- Share the project
- Support via App Store purchase or donation

### Getting Started
1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to your branch
5. Open a Pull Request

For feature requests or inquiries:
- Email: btbishop93@gmail.com
- GitHub Issues: For bugs and improvements
 
