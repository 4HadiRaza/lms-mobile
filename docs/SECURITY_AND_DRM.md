# Security, DRM & Content Protection: Mobile App

This document outlines the security architecture, content protection measures, and export compliance declarations implemented in `lms-mobile`.

---

## 🛡️ 1. Anti-Screen Capture & Recording Prevention

To safeguard proprietary tax lectures and course slides, `lms-mobile` enforces active DRM protection using the **`screen_protector`** package (`lib/widgets/security_wrapper.dart`):

* **Android Implementation:**
  * Enforces `FLAG_SECURE` on the Android Window.
  * When a user attempts to take a screenshot, the system displays: `"Can't take screenshot due to security policy"`.
  * During screen mirroring or screen recording, the application window renders as solid black.
* **iOS Implementation:**
  * Applies a secure text field snapshot layer over the iOS window.
  * When screen recording or AirPlay mirroring is detected, the video feed is blanked out to prevent unauthorized recording.

---

## 🔒 2. Single-Device Session Enforcement

* The application stores the student's active JWT in `flutter_secure_storage` and `shared_preferences`.
* Every outgoing network call made by `ApiService` carries the token in the `Authorization: Bearer <token>` header.
* If the student logs into another device (e.g. tablet or second phone), the backend marks the previous session token as invalid.
* On the next API request, the server responds with a `401 Unauthorized` containing `"Session expired"` or `"logged in from another device"`.
* The `ApiService` interceptor detects this response, wipes local tokens, and invokes `NavigationService.navigateToLogin(reason: 'session_expired')`.

---

## 📋 3. App Store & Google Play Compliance Declarations

### iOS App Store (`Info.plist`)
* **Non-Exempt Encryption Key:**
  ```xml
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  ```
  * Declares that the app only utilizes standard operating system encryption (HTTPS/TLS via `NSURLSession` and iOS Keychain), qualifying for exemption under Category 5 Part 2 of US Export Administration Regulations. Zero additional documentation or CCATS approval is required.
* **Privacy Permissions:**
  * `NSCameraUsageDescription`: *"This app requires access to your camera to join virtual classroom video meetings."*
  * `NSMicrophoneUsageDescription`: *"This app requires access to your microphone to participate in virtual classroom audio discussions."*
  * `NSPhotoLibraryUsageDescription`: *"This app requires access to your photo library to attach payment receipts during admission enrollment."*

### Google Play Console (IARC Declarations)
* **User-Generated Content (UGC):** `No` (Content is instructor-provided coursework).
* **Social Media:** `No` (No social feeds or sharing algorithms).
* **Direct Messaging:** `No` (Chat is strictly in-session Zoom lecture chat).
* **Advertising:** `No` (Zero third-party advertising SDKs).
* **Mature Themes:** `None` (Professional educational material).
