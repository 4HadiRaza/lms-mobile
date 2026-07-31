# Dependencies: lms-mobile

Below is the inventory of third-party packages used in `lms-mobile`, based on `pubspec.yaml`.

## Core UI & State
- **`flutter`**: The core SDK.
- **`provider` (^6.1.5+1)**: App-wide state management.
- **`cupertino_icons` (^1.0.8)**: iOS style icons.
- **`google_fonts` (^8.1.0)**: Used for dynamic custom typography (e.g., Inter, Roboto).

## Networking & Data
- **`dio` (^5.10.0)**: Robust HTTP client used for all API requests (`api_service.dart`). Handles interceptors for JWT injection and 401 logouts.
- **`shared_preferences` (^2.5.5)**: Persistent key-value storage used to cache the JWT token and basic user session data.

## Media & Device Integration
- **`cached_network_image` (^3.4.1)**: Used to load and cache remote images (like course thumbnails and user avatars) efficiently.
- **`image_picker` (^1.1.2)**: Allows students to select an image from their gallery for the "payment proof" upload during admission.
- **`webview_flutter` (^4.0.0)** & **`webview_flutter_android` (^4.0.0)**: Used to embed the web-based Zoom Meeting SDK into the mobile app (`EmbeddedZoomScreen`).
- **`youtube_player_flutter` (^9.1.1)**: Used for embedding YouTube videos natively (often for course preview trailers or supplementary lessons).

## Notifications (Firebase)
- **`firebase_core` (^4.12.1)**: Core initialization for Firebase services.
- **`firebase_messaging` (^16.4.3)**: Handles incoming push notifications from FCM (Firebase Cloud Messaging).
- **`flutter_local_notifications` (^20.1.0)**: Displays system-level notifications on the device when an FCM message is received while the app is running.

## Utilities & Security
- **`intl` (^0.20.3)**: Internationalization and date formatting.
- **`shimmer` (^3.0.0)**: Provides skeleton loading animations while data is fetching.
- **`share_plus` (^12.0.2)**: OS-level sharing (e.g., sharing a course link).
- **`url_launcher` (^6.3.2)**: Used to launch external URLs in the device's default web browser.
- **`screen_protector` (^1.5.3)**: A security package used in `SecurityWrapper` to prevent screen recording and screenshotting, preventing piracy of course material and live classes.
- **`pointer_interceptor` (^0.10.1+2)**: Utility to prevent touches from falling through Flutter widgets into underlying platform views (WebViews).
- **`permission_handler` (^11.3.1)**: Requests OS-level permissions (e.g., camera and microphone for Zoom meetings).
