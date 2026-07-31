# Glossary: lms-mobile

This document defines domain-specific terms and conventions used throughout the `lms-mobile` codebase.

- **Batch:** A specific cohort or group of students taking a set of courses over a defined period (e.g., "Summer 2026 Tax Cohort"). Admissions are tied to Batches, not individual courses.
- **Course:** A curriculum containing multiple Modules and Lessons. Courses are assigned to Batches.
- **Module:** A categorized section within a Course, acting as a folder for Lessons.
- **Lesson:** An individual piece of content within a Module (e.g., a video or article).
- **Live Class:** A scheduled, real-time Zoom meeting associated with a specific Course.
- **Recording:** A VOD (Video on Demand) asset created from a past Live Class.
- **Provider:** Refers to the `provider` state management package. Files in `lib/providers/` are classes extending `ChangeNotifier` that manage business logic and UI state.
- **ZAK (Zoom Access Token):** A specialized token required by the Zoom Meeting SDK to authenticate a user as the "Host" of a meeting, allowing them to manage participants and settings.
- **WebView:** The `webview_flutter` widget used to embed web content natively. In this app, it specifically refers to embedding the Next.js frontend's Zoom integration to avoid native SDK complexities.
- **Admission:** The process by which a user with a `pending` or `student` role submits payment proof and course selections to enroll in a Batch. Once approved, the user becomes an active student.
