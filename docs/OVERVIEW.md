# Overview: lms-mobile

## What this application does
`lms-mobile` is a cross-platform mobile application for students of the Premier LMS (Learning Management System). It allows students to browse available courses, apply for admission, view their enrolled classes, join live Zoom sessions, watch recorded lectures, and manage their profiles. It acts as the student-facing companion to the web-based admin portal. 

## Tech Stack
- **Framework:** Flutter (SDK `^3.9.2`)
- **State Management:** Provider (`^6.1.5+1`)
- **Networking:** Dio (`^5.10.0`)
- **Local Storage:** Shared Preferences (`^2.5.5`)
- **Web/Embedded Views:** WebView Flutter (`^4.0.0`) (Used to embed the frontend Next.js Zoom Meeting view)
- **Push Notifications:** Firebase Cloud Messaging (`^16.4.3`) & Flutter Local Notifications (`^20.1.0`)
- **UI/Styling:** Google Fonts (`^8.1.0`), Cupertino Icons

## High-Level Architecture
The mobile app operates strictly as a consumer of the backend API (`PREMIER_LMs_backend_`). It does not have its own database. 
- **Backend Communication:** The app communicates with the backend via REST APIs (using `Dio`) for authentication, data fetching (courses, classes, batches), and admission submission. It relies on JWT bearer tokens for authenticated requests.
- **Frontend Interfacing (WebViews):** For live Zoom meetings, the app relies on the `premier_LMS_Frontend` Next.js application. Instead of using a native Zoom SDK, it embeds the frontend's Zoom meeting room (`/dashboard/classes/[id]`) inside a `WebViewWidget` (`embedded_zoom_screen.dart`), intercepting permissions and overriding styles to make the web app feel native.

## Folder Structure
- `android/` - Native Android project files and configuration (e.g., permissions, Firebase config).
- `ios/` - Native iOS project files and configuration (e.g., Info.plist, Podfile).
- `lib/` - The core Flutter Dart source code.
  - `config/` - App-wide configurations, including theme data and API base URLs (`api_config.dart`).
  - `models/` - Data classes/entities representing backend JSON objects (e.g., `Course`, `User`, `LiveClass`).
  - `providers/` - State management controllers handling business logic and API orchestration (e.g., `AuthProvider`, `CoursesProvider`).
  - `screens/` - UI pages representing full views (e.g., login, home, live classes, profile).
  - `services/` - Core utility services, primarily `ApiService` for HTTP requests and token interception.
  - `widgets/` - Reusable UI components (e.g., cards, buttons, global layout wrappers).
- `test/` - Flutter unit and widget tests.
- `web/` - Flutter web entry point (though primarily targeted for mobile).
