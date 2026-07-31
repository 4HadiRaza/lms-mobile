# Setup Instructions: lms-mobile

## Prerequisites
- **Flutter SDK:** `^3.9.2` (or compatible 3.x version)
- **Dart SDK:** Bundled with Flutter
- **Android Studio** / Android SDK (for Android build)
- **Xcode** (for iOS build, requires macOS)
- **CocoaPods** (for iOS dependencies)

## Step-by-Step Local Setup

1. **Clone the repository:**
   Ensure you are in the `lms-mobile` directory after cloning the workspace.

2. **Install Flutter Dependencies:**
   Run the following command in the `lms-mobile` directory:
   ```bash
   flutter pub get
   ```

3. **Install iOS Dependencies (Mac only):**
   ```bash
   cd ios
   pod install
   cd ..
   ```

4. **Run the Application:**
   Start an Android Emulator or iOS Simulator, then run:
   ```bash
   flutter run
   ```

## Environment Variables & Configuration
This app does **not** use a `.env` file. Instead, API URLs and configurations are hardcoded and conditionally compiled based on the environment in `lib/config/api_config.dart`.

**Key Configurations in `api_config.dart`:**
- `_prodUrl`: The production backend URL (default: `https://premier-l-ms-backend-lhy5.vercel.app/api`).
- `_localUrlWebAndIos` / `_localUrlAndroid`: Localhost URLs for testing against a local backend. 
- `useProdInDebug`: A boolean flag (default `true`). If set to `true`, the app will connect to the production backend even when running locally in debug mode. Change this to `false` if you want to test against a local instance of `PREMIER_LMs_backend_`.

## Common Setup Errors & Resolution
- **Missing Firebase Config Files:** 
  The app uses `firebase_core` and `firebase_messaging`. If you attempt to build the app and receive a "missing google-services.json" or "missing GoogleService-Info.plist" error, it is because these secrets are not checked into source control. You must obtain them from the Firebase Console for the Premier LMS project and place them in `android/app/` and `ios/Runner/` respectively.
- **WebView Debugging on iOS:**
  If the Zoom meeting (WebView) fails to load on iOS simulators, ensure you have an active internet connection on the simulator, as it requires fetching the Next.js frontend URL over the network.
