# Premier LMS Mobile App (`lms-mobile`)

The official cross-platform mobile application for **Premier LMS** (**Premier Tax School** / **Premier Academy**), built using Flutter (Dart 3.9+). 

Available on Android (Google Play) and iOS (Apple App Store).

---

## 📱 Core Features & User Experience

1. **Course Explorer & Enrollment:**
   * Browse certified tax and accounting courses with instructor credentials and syllabus details.
   * View enrolled batches, upcoming lecture schedules, and lesson checklists.

2. **Protected Live Zoom Classroom:**
   * Join live interactive lectures via an embedded `WebViewWidget` (`embedded_zoom_screen.dart`).
   * Seamless landscape and portrait auto-rotation with edge-to-edge full-screen video.
   * Native Flutter control overlays for microphone mute, video toggle, hand-raising, and speaker selection.
   * In-class live chat bridge extracting Zoom messages and allowing real-time chat from Flutter.

3. **Recorded Lectures Player:**
   * Stream high-definition past lecture recordings with secure time-limited token verification.
   * Track playback history and watched durations.

4. **Security & Anti-Piracy DRM:**
   * Global `SecurityWrapper` powered by `screen_protector` prevents screenshots and turns the display black during screen-recording on iOS and Android.
   * Single-device session protection: logging in from another device terminates the previous mobile session immediately.

---

## 🛠️ Tech Stack & Key Packages

| Category | Package / Dependency |
| :--- | :--- |
| **Framework** | Flutter (SDK `^3.9.2`), Dart 3.x |
| **State Management** | `provider: ^6.1.5+1` |
| **HTTP Client** | `dio: ^5.10.0` (with JWT interceptor) |
| **Security & Storage** | `screen_protector: ^1.5.3`, `flutter_secure_storage: ^9.2.4`, `shared_preferences: ^2.5.5` |
| **Web & Zoom View** | `webview_flutter: ^4.0.0`, `webview_flutter_android: ^4.0.0`, `webview_flutter_wkwebview: ^3.13.0` |
| **Media & UI** | `youtube_player_flutter: ^9.1.1`, `cached_network_image: ^3.4.1`, `shimmer: ^3.0.0`, `google_fonts: ^8.1.0` |
| **Push Notifications** | `firebase_core: ^4.12.1`, `firebase_messaging: ^16.4.3`, `flutter_local_notifications: ^20.1.0` |

---

## 📂 Project Structure

```
lms-mobile/
├── android/                 # Android native gradle config, manifest, signing keys
├── ios/                     # iOS native Xcode workspace, Podfile, Info.plist
├── assets/                  # App icons, splash assets, and App Store screenshot packs
├── lib/
│   ├── main.dart            # App entrypoint, SecurityWrapper initialization, route builder
│   ├── config/
│   │   ├── api_config.dart  # Central API endpoint registry & base URL switching
│   │   └── theme.dart       # App color palette (Forest Green & Gold), typography, buttons
│   ├── models/              # Immutable data models (User, Course, LiveClass, Batch)
│   ├── providers/           # ChangeNotifier state managers (AuthProvider, CoursesProvider, ClassesProvider)
│   ├── screens/             # UI Views
│   │   ├── auth/            # Login, password reset
│   │   ├── home/            # Dashboard, upcoming classes, enrolled courses
│   │   ├── courses/         # Course list, course detail, syllabus
│   │   ├── live/            # Embedded Zoom meeting screen with JS bridge
│   │   ├── recordings/      # Video archive player
│   │   └── profile/         # Account details, session info, logout
│   ├── services/            # ApiService (Dio singleton), AuthService, NavigationService
│   └── widgets/             # Reusable UI cards, loading skeletons, security wrappers
└── docs/                    # Technical guides and API specifications
```

---

## 🏃 Getting Started & Local Development

### 1. Prerequisites
* Flutter SDK (3.9.2 or higher)
* Android Studio / Xcode

### 2. Install Packages
```bash
flutter pub get
```

### 3. Run Locally
```bash
# Debug mode on connected simulator / emulator
flutter run

# Point to local backend (toggle in lib/config/api_config.dart):
# static const bool useProdInDebug = false;
```

### 4. Build Bundles for Release
```bash
# Android App Bundle (Google Play)
flutter build appbundle --release

# iOS Archive (App Store)
flutter build ipa --release
```

---

## 📚 Technical Documentation

* 🏛️ [Mobile Architecture & State Management](file:///c:/Users/user/Desktop/Downloads/premier_lms_mobile/lms-mobile/docs/ARCHITECTURE.md)
* 📡 [API Endpoints Reference](file:///c:/Users/user/Desktop/Downloads/premier_lms_mobile/lms-mobile/docs/API_REFERENCE.md)
* 📹 [Embedded Zoom Screen & JS Bridge](file:///c:/Users/user/Desktop/Downloads/premier_lms_mobile/lms-mobile/docs/ZOOM_BRIDGE_AND_HYBRID_VIEW.md)
* 🛡️ [Security, DRM & Anti-Screen Capture](file:///c:/Users/user/Desktop/Downloads/premier_lms_mobile/lms-mobile/docs/SECURITY_AND_DRM.md)
