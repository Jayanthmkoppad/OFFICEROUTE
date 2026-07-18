# CHANGELOG

## 2026-07-16 - Enterprise Profile Final Pass

Changed:

- Consolidated personal and organization operations into the Enterprise Profile entry point.
- Reused one organization listener for users, attendance, visits, and live locations; notification streams remain user-scoped.
- Added organization KPIs, employee-directory preview, compact comparison charts, top engineers/branches, operational ranks, and rule-based organization summary.
- Added monthly, quarterly, yearly, and Today/Week/Month performance calculations with trend indicators.
- Added current activity, carry-forward visits, recent notifications, complaints, and task dependency state.
- Completed account-health indicators and navigation-only admin shortcuts.
- Removed duplicate and out-of-scope Profile sections and dead notification/action builders.

Preserved:

- No Firestore collections, persistent models, upload services, Phase 3 modules, or external AI integrations were added.
- Flutter analyze, test, and run were not executed per instruction.

## 2026-07-16 - Phase 1 Completion and Phase 2 Entry

Changed:

- Extended the existing user model and `users` documents with approved employee profile metadata and preferences.
- Added realtime profile-detail editing, experience and completion calculations, missing-field health, and persisted runtime theme-mode infrastructure.
- Added Organization Administration using existing employee, attendance, visit, and live-location data.
- Added workforce metrics, enterprise directory controls, employee operational detail, analytics, branch/department comparisons, and admin navigation shortcuts.

Created:

- Organization operations service, controller, and administration screen.

Blocked:

- Personal/organization documents and profile-photo upload require absent Firebase Storage/document/picker/cropper architecture.
- Biometrics and full runtime localization require absent plugins/resources.
- Company configuration, shifts, holidays, policies, and organization rules require approved owning backends.
- Existing hard-coded module colors still need a dedicated theme-fidelity pass for complete Light-mode presentation.

Validation:

- Flutter analyze, test, and run were intentionally not executed per task instruction.

## 2026-07-16

### Enterprise Profile Module - Phase 1

Changed:

- Expanded Profile into a realtime Personal Operations Center.
- Aggregated existing users, attendance, customer visits, notifications, notification preferences, complaints, reports, live location, and location-permission data.
- Added compact responsive KPI navigation, performance ranges, personal operations, rule-based smart summary, notification preview/actions, activity timeline, settings, account health, and admin navigation shortcuts.
- Added safe partial phone updates to the existing `users` collection and realtime watchers for existing user and notification records.

Preserved:

- No new Firestore collections or persistent models were created.
- No organization, branch, fleet, system administration, RBAC, device management, automation, integrations, or audit-log functionality was added.

TODO:

- Documents, reimbursements, approvals, messages, device telemetry, organization ranking, and extended employee metadata remain blocked by missing owning backends.
- Flutter analyze, test, and run were intentionally not executed per task instruction.

## 2026-07-12

### Map UI Foundation Complete

Changed:

- Marked the current Map module as `Map UI Foundation Complete`.
- Accepted the mode-based Map architecture analysis as the future expansion direction.
- Froze the current Map UI as the shared GoogleMap foundation for future tracking modes.

Preserved:

- No Map UI implementation changes were made for Cab Tracking, Customer Locations, Team Tracking, or Office View.
- Existing bottom navigation, Attendance, Visits, Profile, Reports, Complaints, Firebase, and Firestore architecture remain unchanged.

Next:

- Location Foundation will be the next development phase.
- Location Foundation will focus on reliable current location, foreground and background updates, permissions, live location, location history, Firestore strategy, battery optimization, and security/privacy.

### Complaint Register Module

Created:

- `complaint_model.dart`
- `complaint_service.dart`
- `complaint_controller.dart`
- `complaint_register_screen.dart`

Added:

- Firestore-backed `complaints` collection integration.
- Complaint registration form covering customer, machine/vehicle, purchase, warranty, complaint, media reference, GPS, and visit-planning data.
- Optional GPS capture through the existing location controller.
- Recent complaints summary and history on the Complaint Register screen.
- Optional `Visit Required` workflow that creates a planned customer visit through the existing Customer Visits controller and links the created visit ID back to the complaint.
- Home Dashboard Quick Action replacement: `Map` was replaced with `Complaint Register`.

Preserved:

- Bottom navigation Map tab.
- Existing Attendance, Visits, Reports, Profile, Home, Firebase configuration, and routing architecture.

Verified:

- `flutter --no-version-check analyze`: no issues found.

## 2026-07-11

### Sprint 7 - Final Premium Polish

Changed:

- Added shared premium UI widgets for cards, section headers, status chips, icon chips, text fields, loading states, error states, and empty states.
- Connected Notifications, Reports, and Manager from Home quick actions while preserving the existing bottom navigation.
- Standardized responsive premium layouts across the new sprint screens.
- Preserved Google Maps placeholder behavior and did not re-investigate Maps configuration.

Verified:

- `flutter --no-version-check analyze`: no issues found.

### Sprint 6 - Performance

Changed:

- Added bounded Firestore reads for attendance, visits, and notifications.
- Reused existing services/controllers for report and manager aggregation instead of duplicating backend architecture.
- Added focused tests for expanded Attendance and Customer Visit models.
- Cleaned up analyzer warnings.

Verified:

- `flutter --no-version-check analyze`: no issues found.

Blocked:

- `flutter test --no-pub -r expanded` remains blocked because the local Flutter test command wrapper is still open silently with no returned result.

### Sprint 5 - Manager Foundation

Created:

- `manager_employee_summary_model.dart`
- `manager_service.dart`
- `manager_controller.dart`
- `manager_screen.dart`

Added:

- Employee list and employee cards.
- Employee live status derived from today's attendance.
- Attendance summary and visit summary per employee.
- Search and status filters.
- Responsive premium manager UI.

### Sprint 4 - Reports and Analytics

Created:

- `report_summary_model.dart`
- `reports_service.dart`
- `reports_controller.dart`
- `reports_screen.dart`

Added:

- Dashboard cards for attendance, hours, visits, and distance.
- Attendance analytics.
- Visit analytics.
- Distance analytics from visit GPS coordinates.
- Weekly and monthly custom charts.
- Firestore aggregation over existing attendance and customer visit records.
- Export placeholders.

### Sprint 3 - Notification Module

Created:

- `app_notification_model.dart`
- `notification_preferences_model.dart`
- `notification_service.dart`
- `notification_controller.dart`
- `notification_center_screen.dart`

Added:

- Notification Center.
- Unread badge and notification history.
- Local in-app notification creation.
- Firestore-backed notification preferences.
- Firebase Cloud Messaging placeholders.
- Premium responsive notification UI.

Known limitation:

- OS-level local notifications and FCM token handling require notification plugins and platform configuration. This sprint keeps those as explicit placeholders while implementing Firestore-backed in-app notification behavior.

### Sprint 2 - Attendance Module Polish

Changed:

- Expanded attendance records with break start, total break minutes, check-in/check-out GPS coordinates, location validation status, and sync status.
- Added Firestore service/controller methods for attendance history, monthly records, break start, break end, and GPS-backed check-in/check-out.
- Rebuilt Attendance as a premium responsive workspace with working hours, break timer, monthly summary, calendar, history, location validation, sync/offline status, loading state, and error state.

Verified:

- `flutter --no-version-check analyze`: no issues found.

Blocked:

- `flutter test --no-pub -r expanded` remains blocked by the local Flutter test command wrapper staying open silently with no returned result.

### Sprint 1 - Customer Visit Module

Changed:

- Expanded the customer visit model with customer phone, vehicle details, motor serial number, controller serial number, warranty, issue category, issue description, parts used, technician notes, photo references, video placeholder status, signature placeholder status, GPS coordinates, and completion timestamps.
- Added Firestore service/controller support for customer history, visit updates, GPS-backed check-in, GPS-backed check-out, photo references, and explicit visit completion.
- Rebuilt Customer Visits as a premium searchable workspace with summary metrics, status filters, responsive visit cards, loading states, error states, and empty states.
- Added a customer visit detail screen with visit timer, customer details, service details, GPS capture status, customer history, media/signature placeholders, and completion workflow.

Verified:

- `flutter --no-version-check analyze`: no issues found.

Blocked:

- `flutter test --no-pub -r expanded` was attempted, but the local Flutter test command wrapper stayed open silently and did not return a result.

## 2026-07-10

### Premium Home Dashboard

Changed:

- Rebuilt the Home tab into a premium Nothing OS inspired dashboard.
- Kept the existing Flutter architecture and `HomeScreen` navigation shell.
- Reused existing Profile, Attendance, Customer Visits, and Location controllers.
- Preserved Firebase Authentication, Firestore, Attendance logic, Customer Visits logic, and Profile logic.
- Added live greeting, employee name, profile avatar, duty status, working hours, today's attendance summary, today's customer visits, quick actions, and responsive premium cards.
- Restyled bottom navigation as a floating dark premium navigation surface.
- Added dashboard page transition, intro animation, and animated summary cards.
- Added a premium map preview placeholder because Google Maps tile rendering remains blocked by external Google Cloud configuration.

Verified:

- `flutter --no-version-check analyze`: no issues found.

Blocked:

- `flutter test` was attempted multiple times, including a targeted test run, but the local Flutter test command wrapper stayed open with no output and no visible active Flutter test process.

## 2026-07-07

### Backend Stabilization

Fixed:

- Removed the automatic sign-out after successful Firebase Authentication when the Firestore user profile document is missing.
- Added Firestore user document recovery with `FirestoreService.getOrCreateUser()`.
- Updated login verification to load or create `users/{uid}` instead of ending the session.
- Updated Profile loading to repair missing user documents during restored sessions.

Verified:

- Firebase Authentication remains successful.
- User remains logged in after HomeScreen opens.
- Profile loads the Firestore user document.
- Attendance loads today's record.
- Navigation remains stable across Home, Map, Attendance, Visits, and Profile tabs.
- No unexpected `signOut()` call was observed after the fix.

### Customer Visits

Created:

- `customer_visit_model.dart`
- `customer_visit_service.dart`
- `customer_visit_controller.dart`
- `customer_visit_screen.dart`

Added:

- Customer Visits Firestore model.
- Customer Visits Firestore service.
- Customer Visits controller.
- Customer Visits screen.
- Bottom navigation tab for Visits.
- Create visit dialog.
- Visit check-in and check-out service hooks.

Verified:

- Customer Visits tab loads on the physical Android device.
- Existing visit records load from Firestore.
- Customer Visits read path produced no runtime Firestore errors during verification.

### Google Maps Stabilization

Changed:

- Updated the Android manifest Maps API key to the Firebase Android API key for `com.example.officeroute`.
- Enabled `myLocationEnabled`, the My Location button, and explicit Android zoom controls on `MapScreen`.

Verified:

- Android package, namespace, applicationId, MainActivity package, and Firebase package all resolve to `com.example.officeroute`.
- Installed debug SHA-1 is `E5:A1:ED:03:27:AC:F0:3D:C3:AC:13:66:25:0B:61:3A:F2:9E:A9:DD`.
- Installed debug SHA-256 is `87:70:54:46:41:50:13:F0:19:AD:7A:AC:E0:28:5B:ED:8B:D2:1F:51:9B:66:9B:A9:DC:53:65:68:80:E7:88:3A`.
- APK manifest contains Maps key `AIzaSyC0twUhPfkynJW4dxVaNHsv6LA3nw5QF3k`.
- Physical phone shows GoogleMap, Google logo, zoom controls, and My Location control.
- Physical phone still shows a blank white map tile area.

Required external action:

- In Google Cloud Console project `officeroute-96b30`, enable billing, enable `Maps SDK for Android`, restrict API key `AIzaSyC0twUhPfkynJW4dxVaNHsv6LA3nw5QF3k` to `Maps SDK for Android`, and add Android restriction `E5:A1:ED:03:27:AC:F0:3D:C3:AC:13:66:25:0B:61:3A:F2:9E:A9:DD;com.example.officeroute`.

### Validation

- `flutter pub get`: passed.
- `flutter analyze`: no issues found.
- `flutter test`: all tests passed.
- `flutter clean`: passed.
- `flutter run -d 3C15AU00F1W00000 --no-resident`: built and installed on CPH2707.
- Android debug APK built successfully.
- Patched APK installed successfully on CPH2707.

### Remaining

- Google Maps tile rendering remains blocked until the Google Cloud Console action above is completed.
Improved AI debugging workflow.

Added structured investigation policy to reduce wasted AI execution time and improve root cause analysis.
