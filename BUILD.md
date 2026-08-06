# Building the app

The app is made for iOS and iPadOS (With limited support for Mac and Apple Vision). The app can be built using Xcode.

## Prerequisites

- **Signing:** Paid Apple Developer account[^1]
- **Xcode:** Version 27.0 or later
- **macOS:** Version 26.4 or later[^2]

## Setup

1. Clone the repository with `gh repo clone Somebud0180/Today` or download it as a ZIP under the code button in the repo page.
2. Open `Today.xcodeproj` in Xcode.
3. Configure the signing team under **Today > Targets: Today > Signing & Capabilities**.
4. (Optional?) You may have issues with using the default bundle identifier/iCloud identifier, change them to something else unique.

## Running the app
1. Run the app via the menubar (Product > Run) or the toolbar (the play button).

[^1]: Some entitlements such as iCloud require proper signing
[^2]: Minimum supported macOS version by Xcode 27
