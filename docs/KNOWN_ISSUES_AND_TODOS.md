# Known Issues & TODOs: lms-mobile

Based on a thorough code review, the following issues, inconsistencies, and technical debt have been identified:

## Code Issues & Inconsistencies
- **Missing Firebase Config Files:** 
  The codebase includes dependencies for `firebase_core` and `firebase_messaging`, but the required `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are missing from the repository. Builds will fail or push notifications will not work until these are manually provided.
- **Hardcoded Configuration Values:**
  - `lib/config/api_config.dart`: The production API URL and frontend URL are hardcoded strings rather than being loaded from an environment file (`.env`). Changing environments requires changing source code.
  - `lib/config/api_config.dart` (Line 16): `static const bool useProdInDebug = true;` is hardcoded, meaning local development builds will hit the production backend by default unless a developer manually changes this boolean.
- **Data Model Mocking:**
  - `lib/models/course.dart` (Line 115): The `fromApiJson` factory function contains several hardcoded fallback values if the backend doesn't provide them. E.g., `instructor` defaults to `'Premier Academy Faculty'`, `enrollmentCount` defaults to `120`, and `requirements` defaults to `['Basic understanding of accounting principles']`. This creates a risk of presenting inaccurate data if the backend schema changes or fails to provide these fields.

## TODOs & FIXMEs
- *No explicit `TODO` or `FIXME` comments were found in the `lms-mobile` codebase.*

## Architectural Limitations
- **Screen Sharing on Mobile:** 
  The app relies on `webview_flutter` to embed the Zoom Meeting SDK. Native mobile WebViews do not support the `getDisplayMedia` WebRTC API. Consequently, students cannot share their screens from the mobile app. A JavaScript polyfill was injected to make the button *visible*, but tapping it simply throws an alert explaining the limitation. To support true mobile screen sharing, a native Flutter Zoom SDK would need to be implemented.
