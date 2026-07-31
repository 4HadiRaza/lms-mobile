# Features: lms-mobile

This document provides an inventory of the distinct user-facing features and screens available in the `lms-mobile` application.

## Authentication & Onboarding
- **Login (`LoginScreen`):** Allows existing students to sign in using their email and password. Features a "Forgot Password?" prompt (UI only).
- **Sign Up (`SignupScreen`):** Allows new users to create an account.
- **Under Review (`UnderReviewScreen`):** A blocking screen shown to users whose `role` is `pending`. Prevents access to the main app until an administrator approves their account.

## Course Browsing & Admission
- **Course Catalog (`HomeScreen` / `ExploreTab`):** Displays available courses, active batches, and featured content.
- **Course Details (`CourseDetailScreen`):** Shows comprehensive information about a course, including description, syllabus (modules & lessons), instructor bio, pricing, and reviews.
- **Admission Application (`AdmissionScreen`):** A multi-step form where students apply for enrollment:
  1. Select an active Batch.
  2. Select one or more Courses from that batch.
  3. Upload a payment proof receipt (image picker).
  4. Submit for administrator review.

## Student Dashboard & Learning
- **Live Classes (`LiveClassesScreen`):** Displays a schedule of upcoming Zoom sessions. Includes a countdown timer for the next class.
- **In-App Zoom Meetings (`EmbeddedZoomScreen`):** Allows students to join live classes directly within the app using an embedded WebView that loads the web platform's Zoom SDK implementation. Includes CSS overrides and polyfills for a native feel.
- **Recordings (`RecordingsScreen`):** A library of past class recordings.
- **Video Player (`VideoPlayerScreen`):** A custom video player interface for watching recorded lectures. It relies on short-lived JWT tokens (`recording-token`) for secure playback. Includes a screen-protector overlay to prevent piracy.

## Profile & Settings
- **Profile (`ProfileScreen`):** Displays the student's name, email, avatar, and a list of their enrolled courses.
- **Change Password:** A modal/dialog allowing the user to update their account password.
- **Logout:** Clears local storage tokens and returns the user to the login screen.
