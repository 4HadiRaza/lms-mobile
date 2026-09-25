# API Reference: lms-mobile

*Note: `lms-mobile` is a client application. It consumes the `PREMIER_LMs_backend_` APIs. Below is the complete catalog of endpoints utilized by the mobile app based on [`lib/config/api_config.dart`](file:///c:/Users/user/Desktop/Downloads/premier_lms_mobile/lms-mobile/lib/config/api_config.dart) and its Provider services.*

---

## 🔐 Authentication (`AuthProvider`)
* `POST /auth/login`: Authenticates with email and password. Returns JWT access token and user profile. Enforces single-device session locking.
* `POST /auth/register`: Submits student registration.
* `GET /auth/profile`: Fetches current user profile and active enrollments.
* `POST /auth/logout`: Invalidates the device session on the backend.
* `POST /auth/change-password`: Updates password.
* `POST /auth/forgot-password`: Requests password reset email.
* `POST /auth/reset-password`: Completes password reset with verification code.

---

## 📚 Courses (`CoursesProvider`)
* `GET /courses/all`: Fetches the complete catalog of offered courses for browsing and admission.
* `GET /courses`: Fetches courses enrolled by the authenticated student.
* `GET /courses/:id`: Fetches detailed course syllabus, modules, lessons, and reviews.

---

## 📅 Batches & Admissions (`BatchesProvider`)
* `GET /batches/public`: Fetches active cohorts open for enrollment.
* `POST /admissions`: Submits student application with attached personal documents and bank payment receipts.

---

## 🎥 Live Classes & Zoom (`ClassesProvider`)
* `GET /classes/public/upcoming`: Fetches upcoming classes across the institution.
* `GET /classes/my/upcoming`: Fetches upcoming lectures specifically for the batches the student is enrolled in.
* `GET /classes/my/past`: Fetches completed lectures.
* `GET /classes/count/upcoming`: Badge count of pending live sessions.
* `POST /classes/:id/join`: Fetches Zoom meeting credentials, user role signature (`HMAC-SHA256`), and permission flags.

---

## 📼 Recorded Lectures (`RecordingsProvider`)
* `GET /classes/my/recordings`: Fetches archived cloud recordings for the student's courses.
* `POST /classes/:id/recording-token`: Issues a signed, time-limited token to authorize video streaming.
* `GET /classes/recording/verify`: Validates playback token for streaming authorization.

---

## 📁 Media & Uploads
* `POST /uploads`: Uploads user profile photo or admission payment slip.
* `ApiConfig.mediaUrl(path)`: Dynamically resolves thumbnail URLs against the backend or Cloudinary CDN.
