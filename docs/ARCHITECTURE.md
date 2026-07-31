# Architecture: lms-mobile

## Key Modules & Responsibilities

- **Screens (`lib/screens/`):** 
  Flutter `StatefulWidget` or `StatelessWidget` classes that represent full-page views. They focus exclusively on UI layout and routing, deferring business logic to Providers.
  
- **Providers (`lib/providers/`):** 
  The brain of the application. They extend `ChangeNotifier` and handle data fetching, state management, and business logic. They call the `ApiService` and update their internal state, which triggers a rebuild of the UI components listening to them.

- **Models (`lib/models/`):** 
  Dart data classes representing the domain entities (e.g., `Course`, `LiveClass`). They contain `fromJson` factory methods to parse the API responses safely.

- **Services (`lib/services/`):** 
  Stateless utility classes. The most critical is `ApiService` (`lib/services/api_service.dart`), a Singleton wrapping the `Dio` HTTP client. It handles global concerns like attaching JWT tokens to outgoing requests and listening for 401 Unauthorized responses to force a user logout.

- **Widgets (`lib/widgets/`):** 
  Reusable UI components. A notable widget is the `SecurityWrapper` which wraps the entire `MaterialApp` to apply screen-recording and screenshot protections via the `screen_protector` package.

## State Management Approach
The app uses the **Provider** package (`MultiProvider` wrapping the app root). 
- **Global State:** Providers like `AuthProvider` hold global state (e.g., current user, JWT token) that affects the whole app.
- **Feature State:** Feature-specific providers (e.g., `CoursesProvider`, `BatchesProvider`) load and cache data for specific domains. 
- **Consumption:** UI components use `Consumer<T>` or `context.watch<T>()` to reactively rebuild when the provider calls `notifyListeners()`.

## Core Data Flows

### 1. Authentication & App Startup Flow
1. **Startup:** `main.dart` initializes `PremierLMSApp`. The `_buildHomeRoute` checks `AuthProvider.isLoading`.
2. **Auto-Login:** `AuthProvider` checks `SharedPreferences` for a cached JWT. If found, it fetches the user profile from `/auth/profile`.
3. **Login Request:** If no token exists, the user enters credentials on `LoginScreen`. `AuthProvider.login()` calls `ApiService`, receives the JWT, saves it, and updates state.
4. **Routing:** `_buildHomeRoute` sees `auth.isLoggedIn == true` and routes to `MainLayout`, unless `auth.user!.isActive` is false, in which case it routes to `UnderReviewScreen`.

### 2. Live Class (Zoom) Join Flow
1. **List:** User navigates to Live Classes tab. `ClassesProvider` fetches upcoming classes.
2. **Join Action:** User taps "Join". The app navigates to `EmbeddedZoomScreen` passing the class ID and Zoom credentials.
3. **WebView Initialization:** `EmbeddedZoomScreen` initializes a `WebViewWidget` pointing to the Next.js frontend route: `https://premier-lms-frontend.vercel.app/dashboard/classes/[id]?fromApp=true`.
4. **JS Injection:** The Flutter app injects JavaScript into the WebView to hide standard web UI elements and polyfill `getDisplayMedia` (to fix UI rendering issues with the screen share button).
5. **Meeting:** The user participates via the embedded web view.

### 3. Admission Application Flow
1. **Data Fetch:** `BatchesProvider` fetches active public batches, and `CoursesProvider` fetches courses.
2. **Form Input:** User selects a batch, courses, and uploads payment proof via `ImagePicker`.
3. **Submission:** `BatchesProvider.submitAdmission()` creates a `FormData` object (including the image file as a `MultipartFile`) and posts to the `/admissions` endpoint.
4. **Status Update:** The backend creates a pending admission. The user is redirected to `UnderReviewScreen` until an admin approves them.
