# API Reference: lms-mobile

*Note: `lms-mobile` is a client application. It does not expose APIs, but consumes the `PREMIER_LMs_backend_` APIs. Below is a reference of the endpoints this app relies on, based on `lib/config/api_config.dart` and the Provider implementations.*

## Authentication (`AuthProvider`)
- `POST /auth/login`: Submits email/password. Expects JWT token and user object.
- `POST /auth/register`: Submits user registration details.
- `GET /auth/profile`: Fetches the current user's profile based on the Bearer token.
- `POST /auth/change-password`: Updates user password.

## Courses (`CoursesProvider`)
- `GET /courses/all`: Fetches the complete list of courses for the admission flow.
- `GET /courses`: Fetches the paginated list of courses the user is enrolled in.

## Batches & Admissions (`BatchesProvider`)
- `GET /batches/public`: Fetches active batches available for enrollment.
- `POST /admissions`: Submits an admission application. Uses `multipart/form-data` to include the `paymentProof` file along with `batchId` and `courseIds`.

## Classes (`ClassesProvider`)
- `GET /classes/public/upcoming`: Fetches upcoming classes (often used for dashboard widgets).
- `GET /classes/my/upcoming`: Fetches the current student's scheduled classes that haven't happened yet.
- `GET /classes/my/past`: Fetches the current student's completed classes.
- `GET /classes/count/upcoming`: Fetches the total count of upcoming classes for badge notifications.
- `GET /classes/:id/join`: Fetches Zoom credentials (Meeting ID, Passcode, SDK Key, Signature) required to join a specific class.

## Recordings (`RecordingsProvider`)
- `GET /classes/my/recordings`: Fetches a list of past classes that have video recordings available.
- `POST /classes/:id/recording-token`: Requests a short-lived, signed token required to playback a specific recording securely.
