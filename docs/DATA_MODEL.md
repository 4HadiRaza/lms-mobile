# Data Models: lms-mobile

*Note: As this is a client application, these models represent the Dart classes used to parse and hold data returned by the backend API. They are located in `lib/models/`.*

## User (`user.dart`)
Represents the authenticated user.
- **Fields:**
  - `id` (String): Unique identifier.
  - `name` (String): Full name.
  - `email` (String): User's email.
  - `role` (String): User role (`student`, `admin`, `pending`).
  - `avatar` (String): URL to the user's avatar image.
  - `enrolledCourses` (List<String>): Names of courses the user is enrolled in.
- **Computed Properties:** `isAdmin`, `isStudent`, `isPending`, `isActive`, `hasEnrollments`.

## Course (`course.dart`)
Represents a learning course, typically used for the course catalog and detail views.
- **Fields:**
  - `id` (String), `slug` (String), `title` (String), `description` (String), `longDescription` (String).
  - `instructor` (String), `instructorId` (String).
  - `category` (String), `level` (String), `duration` (int, in hours).
  - `price` (double?), `originalPrice` (double?), `discountPercent` (int?).
  - `thumbnail` (String): URL to the course cover image.
  - `modules` (List<Module>): Contains nested `Lesson` objects.
  - `rating` (double), `reviewCount` (int), `enrollmentCount` (int).
  - `tags`, `whatYouWillLearn`, `requirements` (Lists of Strings).
- **Sub-models:** `Module`, `Lesson`, `Instructor`. 
- **Mapping Logic:** Contains complex mapping in `fromApiJson` to handle missing backend fields by providing sensible defaults (e.g., hardcoded instructor info if missing).

## Batch (`batch.dart`)
Represents a cohort/batch that students enroll in.
- **Fields:**
  - `id` (String), `name` (String).
  - `startDate` (DateTime), `endDate` (DateTime).
  - `courses` (List<Course>): Courses included in this batch.
  - `status` (String): Lifecycle state of the batch (e.g., `admission`, `classes`).
  - `isActive` (bool).
  - `totalApplicants` (int).

## LiveClass (`live_class.dart`)
Represents a scheduled Zoom session.
- **Fields:**
  - `id` (String), `topic` (String), `description` (String?).
  - `courseId` (String), `courseName` (String?).
  - `scheduledStart` (DateTime), `duration` (int).
  - `status` (String): E.g., `scheduled`, `completed`.
  - `zoomMeetingId` (String?).
  - `zoomPasscode` (String?).
  - `hostEmail` (String?).

## Recording (`recording.dart`)
Represents a video recording of a past LiveClass.
- **Fields:**
  - `id` (String).
  - `classId` (String), `classTopic` (String).
  - `courseId` (String), `courseName` (String).
  - `videoUrl` (String), `duration` (int), `thumbnailUrl` (String?).
  - `recordedAt` (DateTime).

## Review (`review.dart`)
Represents a student review for a course.
- **Fields:**
  - `id` (String), `courseId` (String), `studentName` (String), `studentAvatar` (String).
  - `rating` (double), `comment` (String).
  - `createdAt` (DateTime).
