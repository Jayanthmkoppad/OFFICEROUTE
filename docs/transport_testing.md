# Driver?Employee transport testing

## Development access

Role preview is opt-in and is never enabled by default. Start a debug preview build with:

```powershell
flutter run --dart-define=OFFICEROUTE_DEV_ACCESS=true
```

The DEV banner and warning identify preview mode. Preview changes Flutter navigation only; it does not change `FirebaseAuth.currentUser`, claims, or `users/{uid}.role`. Use **Use real login** or **Exit Role Preview / Use Real Login** to sign out and return to Firebase login.

For production-equivalent login testing use:

```powershell
flutter run --dart-define=OFFICEROUTE_DEV_ACCESS=false
```

Release builds never enable role preview because the gate also requires `kDebugMode`.

Development diagnostics contain only these safe fields:

- `DEV_AUTH_UID`
- `DEV_AUTH_USER_ROLE`
- `DEV_SELECTED_PREVIEW_ROLE`
- `DEV_IDENTITY_MODE=ui_preview_only`

No token, phone number, address, or coordinate is logged.

## Test modes

### 1. Visual preview

Use the DEV selector to inspect Employee, Cab Driver, Manager, Administrator, and existing role shells. This is not backend end-to-end evidence.

### 2. One-phone sequential account test

1. Sign in with the Employee test UID and verify `users/{uid}.role` is Employee.
2. Configure an approved pickup, request today?s pickup, and mark Ready.
3. Sign out through the real-login flow.
4. Sign in with a distinct Driver UID whose normalized role is `driver` or `cab_driver`.
5. Start duty, verify Available/Ready, select the Employee, and start the trip.
6. Sign out, return to the Employee account, and verify Driver, vehicle, trip, and in-app notification state.
7. Repeat around Driver arrival, pickup, and completion as needed.

A same-UID role preview is invalid as backend E2E proof.

### 3. Real-time test

Use a physical phone signed in as the Driver and a desktop/web/emulator signed in as the Employee. Confirm arrival, persisted waiting timer, pickup, office arrival, completion, and stopped Driver presence after End Duty.

## Controlled fixture

Use separate test identities and the existing collections:

- one Driver UID with role `driver` or `cab_driver`
- one Employee UID with role `employee`
- one active `cab_vehicles` document
- one approved Employee profile pickup
- one deterministic current-day `cab_assignment_members/{dateKey}_{employeeUid}` request

Never reuse one UID for both roles and never mutate `users/{uid}.role` from role preview.
