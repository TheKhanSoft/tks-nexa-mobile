# Mobile ↔ Laravel API contract

Status: draft for backend agreement. Unless explicitly marked confirmed, every path and schema below is a proposal and carries `TODO: BACKEND CONTRACT REQUIRED`.

The mobile app is one evidence source for the existing Laravel attendance engine. Laravel derives the authenticated employee and tenant context, uses server time, verifies evidence, applies shift/schedule/duplicate rules, and creates the authoritative attendance event.

## Cross-cutting rules

- HTTPS is mandatory outside local development. Debug development permits plain HTTP only for `localhost` and `*.localhost`; tenant API bases are accepted only from discovery and must match the mobile allowlist.
- Every request carries a fresh `X-Mobile-Token: <nonce>.<timestamp>.<hmac>` header. Authenticated tenant requests additionally carry the employee Bearer token.
- Tenant APIs derive the tenant from the selected, trusted API context. The client does not send `tenant_id` with each request.
- Tenant endpoints use `Authorization: Bearer <token>` after login.
- JSON requests use `Accept: application/json` and `Content-Type: application/json`.
- `X-Request-ID` is a UUID for diagnostics, not an authentication factor.
- Sensitive POST requests should accept an `Idempotency-Key`. Attendance submission is never automatically retried by the app.
- Server time is authoritative. Client timestamps are evidence capture metadata only.
- Validation errors should use a stable code plus a user-safe message. Do not expose key-verification internals, stack traces, SQL, or tenant details.
- Suggested error envelope:

```json
{
  "error": {
    "code": "stable_machine_code",
    "message": "Safe user-facing message.",
    "request_id": "uuid"
  }
}
```

Common HTTP behavior: `400` malformed request, `401` expired/invalid session, `403` authenticated but disallowed, `404` unavailable resource, `409` conflict/replay/duplicate, `422` field validation, `429` rate limit, `5xx` temporary server failure.

## Default production security posture

The default attendance path requires no new physical hardware. It combines a fresh server challenge, fresh high-accuracy phone location, authoritative campus polygon evaluation, Play Integrity/App Attest, a registered-device signature, mobile face and proper liveness verification, server time, and multi-signal risk analysis. Existing supported institutional cameras are an optional independent corroboration source. No single signal is sufficient proof:

| Signal | Security question |
| --- | --- |
| Phone location | Where does the phone report that it is? |
| Play Integrity / App Attest | Is this likely the genuine app/device environment? |
| Device signature | Is this the registered phone key? |
| Mobile face + liveness | Is this likely the actual employee? |
| Institution camera | Does independently controlled infrastructure see the employee on-site? |
| Server challenge | Is this attempt fresh and non-replayed? |
| Server time | When was it actually submitted/verified? |

Initial tenant-configurable defaults are: mobile attendance enabled; polygon, fresh location, integrity/attestation, registered-device signature, face, and liveness required; institutional camera corroboration enabled only where compatible cameras exist; 15% base camera selection; temporary recent-success minimum around 5–10% but never zero; roughly 40–50% for medium risk, 70–80% for high risk, and 100% for very high risk; approximately five minutes for camera verification; BLE/NFC/UWB/Wi-Fi RTT off. Institutional Wi-Fi is additional confidence only, and mobile data is neutral.

These percentages are starting engineering settings rather than scientifically established fraud probabilities. Authorized tenant administrators may tune them from operational data; normal employee APIs and UI never expose them.

## End-to-end camera-aware attendance flow

1. Laravel issues a fresh attendance challenge.
2. The app captures a fresh location, integrity evidence, device signature, and mobile face/liveness evidence according to policy.
3. Laravel verifies evidence, evaluates the authoritative polygon/accuracy, and calculates risk.
4. Laravel calculates the tenant-configured camera probability and performs unpredictable server-side selection.
5. If camera verification is selected, Laravel first searches existing camera events in the configured window.
6. A matching event corroborates invisibly. Otherwise, if a compatible camera exists, Laravel creates one idempotent camera challenge and returns the employee-safe step-up response.
7. The existing camera/XVR/NVR → Edge Agent → Laravel pipeline reports recognition normally. Laravel correlates that event to the pending challenge without duplicating the attendance event.
8. If no compatible camera exists, Laravel applies the configured secure fallback instead of issuing an impossible challenge.

## Server domain additions

`TODO: BACKEND CONTRACT REQUIRED`

- `AttendanceLocation`: polygon, optional fallback center/radius, required accuracy, enabled flag, camera availability, and supported registered-camera relationships.
- `AttendanceRiskAssessment`: score, level, contributing internal signals, calculated camera probability, policy version, and calculation time. This is internal/admin data.
- `CameraVerificationChallenge`: attendance attempt/challenge, employee, required/expiry times, verification window, status, matched event/device, verification time, risk score and probability snapshots.
- `CameraCorroborationResult`: employee-safe outcome plus internal matched-event reference.
- `AttendanceRiskService`: weighted risk calculation and gradual decay.
- `CameraCorroborationService`: random selection orchestration, invisible recent-event search, challenge creation, event correlation, status, expiry, and availability fallback.

## 1. Tenant directory (central discovery)

- Method: `GET`
- URL: central API base + relative `mobile/v1/tenant-list`
- Production example: `https://api.mydomain.com/mobile/v1/tenant-list`
- Local example: `http://api.localhost:8000/mobile/v1/tenant-list`
- Optional search: `/mobile/v1/tenant-list?search=Beacon`
- Authentication: per-request mobile HMAC header

Flutter generates a cryptographically random 16-byte nonce and current UTC Unix
timestamp in seconds for every request. It calculates the lowercase hexadecimal
`HMAC-SHA256("<nonce>:<timestamp>", mobileSecret)` and sends:

```http
X-Mobile-Token: <nonce>.<timestamp>.<signature>
Accept: application/json
```

Success `200`:

```json
{
  "status": "success",
  "count": 1,
  "data": [
    {
      "id": "01JACTIVEDIR0000000000002",
      "public_id": "01JACTIVEDIR0000000000002",
      "name": "Beacon Industries",
      "slug": "beacon-ind",
      "status": "active",
      "domain": "beacon.your-domain.com",
      "domains": [
        "beacon.your-domain.com",
        "portal.beacon.example"
      ],
      "created_at": "2026-09-17T05:27:06+00:00"
    }
  ]
}
```

The app uses `public_id` as the stable organization identifier. In production it
derives the tenant API base as `https://<domain>/api/mobile`, requires HTTPS,
and validates the primary domain against `TENANT_API_ALLOWED_HOST_SUFFIXES`.
For development only, central `http://api.localhost:8000` causes a returned
domain such as `beacon.localhost` to become
`http://beacon.localhost:8000/api/mobile`. The additional `domains` array is
informational and is not selected automatically.

Because `*.localhost` may not resolve through a native device DNS resolver, the
native development client connects to loopback but sends the original logical
host (for example `Host: api.localhost:8000` or
`Host: beacon.localhost:8000`) so Laravel tenancy still resolves correctly.
Browser previews keep the logical URL because JavaScript cannot set `Host`, and
therefore require Laravel CORS for the mobile route paths and custom headers.

The initial call has no search parameter. Search calls are debounced and send
the trimmed text as `search`. Laravel should return active, mobile-enabled
tenants only, enforce a bounded result count, rate-limit requests, validate a
small timestamp skew, and reject nonce replay during that validity window.

The mobile HMAC key is distributed in the compiled app and can therefore be
extracted from a sufficiently motivated client. Treat the header as an app
compatibility and abuse-control signal, not as employee, tenant, or device
authentication. Employee Bearer authentication and device attestation remain
separate requirements.

## 2. Recent organization behavior

The last confirmed organization is stored in OS-backed secure storage. On every
fresh app start, the app still loads the central tenant directory and shows the
selection screen. If the stored organization is present in the current response,
it is moved to the first row and marked with a star and `Recent`. A tenant no
longer returned by the central directory is not restored as an offline option.

QR resolution searches this same directory by the QR organization identifier;
the app does not accept an arbitrary API URL from a QR code.

## 3. Login (confirmed path; payload pending live verification)

- Method: `POST`
- URL: tenant API base + `/auth/login`
- Full production form: `https://<tenant>.mydomain/api/mobile/auth/login`
- Full local form: `http://<tenant>.localhost:8000/api/mobile/auth/login`
- Authentication: none
- Request:

```json
{
  "login_type": "email",
  "login": "employee@example.invalid",
  "password": "user-entered-password"
}
```

`login_type` is `email`, `cnic`, `employee_code`, or `username`. CNIC is sent
as exactly 13 digits without dashes. Employee ID/code and username are sent as
trimmed strings using the identifier registered by the tenant.

- Success `200`:

```json
{
  "access_token": "opaque-sanctum-compatible-token",
  "token_type": "Bearer",
  "expires_at": "2026-09-16T12:00:00Z",
  "refresh_token": null,
  "employee": {
    "name": "Employee Name",
    "photo_url": "https://<tenant>.mydomain/file/employee_photos/employee.jpg?expires=<epoch>&signature=<signature>"
  }
}
```

- Validation/errors: `401 invalid_credentials`; `403 account_disabled`, `mobile_access_disabled`; `422 validation_failed`; `429 login_rate_limited`.
- Security: never return tenant secrets. Password is used only for this request and never stored/logged. Define token TTL, Sanctum behavior, optional refresh semantics, and session/device binding.
- Employee photos: return a short-lived signed `photo_url`. Native clients may fall back to `Authorization: Bearer <token>` for an unsigned `/file/{path}` URL. Web image elements may use `auth_token` only when a signed URL is unavailable. File responses should use `Cache-Control: private, no-store` so protected photos are not retained by shared/browser caches.

## 4. Refresh session (optional)

`TODO: BACKEND CONTRACT REQUIRED` — omit entirely if Laravel uses non-refreshable Sanctum tokens.

- Method: proposed `POST`
- URL: tenant API base + `/auth/refresh`
- Authentication: agreed refresh-token mechanism; do not also trust an expired access token as proof
- Request: `{"refresh_token":"opaque-refresh-token"}`
- Success `200`: same token fields as login, with refresh-token rotation if supported
- Validation/errors: `401 refresh_expired`, `refresh_reused`, `session_revoked`.
- Security: rotate refresh tokens, detect reuse, revoke token family on reuse, and store tokens hashed server-side where applicable.

## 5. Logout

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `POST`
- URL: tenant API base + `/auth/logout`
- Authentication: Bearer token
- Request: empty JSON object
- Success: `204 No Content`
- Validation/errors: `401 unauthorized`; logout should remain locally completable if the server is unavailable.
- Security: revoke the current mobile token/refresh family. Logout does not automatically revoke the registered device key unless explicitly requested.

## 6. Employee profile/dashboard

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `GET`
- URL: tenant API base + `/profile`
- Authentication: Bearer token
- Request: none
- Success `200`:

```json
{
  "employee": {
    "name": "Employee Name",
    "photo_url": "https://<tenant>.mydomain/file/employee_photos/employee.jpg?expires=<epoch>&signature=<signature>"
  },
  "attendance_summary": {
    "current_status": "not_marked",
    "first_verified_event_at": null,
    "last_verified_event_at": null
  }
}
```

- Validation/errors: `401 unauthorized`; `403 employee_inactive`.
- Security: return only fields needed by the employee UI. Summary is calculated by the Laravel attendance engine.

## 7. Register mobile device/public key

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `POST`
- URL: tenant API base + `/devices`
- Authentication: Bearer token; optionally require recent login/local authorization
- Request:

```json
{
  "key_id": "client-generated-key-reference",
  "public_key": "base64url-or-PEM-public-key",
  "algorithm": "ES256",
  "platform": "android",
  "app_version": "1.0.0",
  "platform_version": "16",
  "device_model": "diagnostic-model",
  "integrity_registration_token": null,
  "attestation": null
}
```

- Success `201`:

```json
{
  "device": {
    "id": "registered-device-id",
    "key_id": "client-generated-key-reference",
    "status": "active",
    "registered_at": "2026-09-16T09:30:00Z"
  }
}
```

- Validation/errors: `409 key_already_registered`, `device_limit_reached`; `422 unsupported_algorithm`, `invalid_public_key`; `403 device_registration_disabled`.
- Security: associate the key with authenticated employee, tenant, device record, and registration time. Never accept a private key. IMEI/MAC/Android ID are not the security identity. Define algorithm, curve, public-key encoding, key-ID ownership, attestation policy, and replacement/recovery rules.

## 8. Registered device status

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `GET`
- URL: tenant API base + `/devices/{registered_device_id}`
- Authentication: Bearer token
- Request: none
- Success `200`: device object containing `id`, `key_id`, `status`, `registered_at`, and optional `revoked_at`
- Validation/errors: `404 device_not_registered`; `403 device_not_owned`.
- Security: employee may query only their own tenant-scoped device. Do not return the stored public key unless operationally necessary.

## 9. Revoke registered device

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `DELETE`
- URL: tenant API base + `/devices/{registered_device_id}`
- Authentication: Bearer token; define recent-auth requirement
- Request: optional `{"reason":"user_requested"}` if DELETE bodies are supported; otherwise a dedicated revoke POST
- Success: `204 No Content`
- Validation/errors: `404 device_not_registered`; `409 device_already_revoked`.
- Security: immediately reject later signatures from the revoked key. Define behavior for current tokens and server challenges.

## 10. Attendance policy

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `GET`
- URL: tenant API base + `/attendance/policy`
- Authentication: Bearer token
- Request: none
- Success `200`:

```json
{
  "version": 1,
  "mobile_attendance_enabled": true,
  "require_location": true,
  "require_face": true,
  "require_liveness": true,
  "require_integrity": true,
  "require_registered_device": true,
  "require_local_biometric": false,
  "allow_device_credentials": false,
  "polygon_geofence_enabled": true,
  "camera_verification_enabled": true,
  "ble_proximity_enabled": false,
  "nfc_proximity_enabled": false,
  "uwb_proximity_enabled": false,
  "wifi_rtt_proximity_enabled": false,
  "maximum_location_accuracy_m": 50,
  "maximum_location_age_seconds": 15
}
```

- Validation/errors: `403 mobile_attendance_disabled`; `409 unsupported_policy_version` if the app cannot satisfy a required field.
- Security: policy is authoritative but not itself proof. Unknown required controls must fail closed. Server re-evaluates current policy on submission. This employee endpoint must not return risk scores, probability bands, exact random-selection parameters, contributing anomaly signals, or the outcome of a future random selection.

Laravel's tenant/admin policy model additionally needs configurable camera probabilities, recent-success reduction with a non-zero minimum, risk weights/bands, gradual risk decay, verification window, and camera-unavailable fallback. Those server-only/admin fields are not part of the normal employee response.

## 11. Attendance locations

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `GET`
- URL: tenant API base + `/attendance/locations`
- Authentication: Bearer token
- Request: none
- Success `200`:

```json
{
  "locations": [
    {
      "id": 51,
      "name": "Main Campus",
      "type": "campus",
      "polygon": [
        [34.1980, 72.0470],
        [34.1990, 72.0470],
        [34.1990, 72.0480],
        [34.1980, 72.0480]
      ],
      "fallback_latitude": 34.1985,
      "fallback_longitude": 72.0475,
      "fallback_radius_m": 100,
      "minimum_required_location_accuracy_m": 50,
      "camera_verification_available": true,
      "enabled": true
    }
  ]
}
```

- Validation/errors: `403 locations_not_available`.
- Security: Laravel stores the authoritative polygon, tests the point, calculates distance/accuracy overlap at the boundary, and chooses `INSIDE`, `BOUNDARY_UNCERTAIN`, or `OUTSIDE`. A boundary-uncertain result requests another fresh fix rather than automatically rejecting. Any client preview is non-authoritative and the attendance submission never sends `inside_polygon` or `inside_geofence`.

## 12. New attendance challenge

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `POST`
- URL: tenant API base + `/attendance/challenge`
- Authentication: Bearer token; registered-device status where policy requires it
- Request:

```json
{
  "action": "attendance_event",
  "device_key_id": "registered-key-id"
}
```

- Success `201`:

```json
{
  "challenge_id": "server-generated-id",
  "challenge": "base64url-random-value",
  "expires_at": "2026-09-16T09:31:00Z",
  "requirements": {
    "location": true,
    "face": true,
    "liveness": true,
    "local_biometric": false,
    "proximity": false,
    "integrity": true,
    "registered_device": true
  }
}
```

- Validation/errors: `403 mobile_attendance_disabled`; `409 active_attempt_exists` only if backend intentionally enforces it; `429 attempts_rate_limited`; `device_not_registered`, `device_revoked`.
- Security: use cryptographically random, single-use challenges with roughly 30–90 second expiry, bound server-side to employee, tenant, session, device, and requested action. A new user attempt gets a new challenge. Do not reveal whether random camera corroboration will be required; that decision occurs only after protected evidence is verified.

## 13. Start face/liveness verification

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `POST`
- URL: tenant API base + `/face-verifications`
- Authentication: Bearer token
- Request metadata:

```json
{
  "challenge_id": "server-generated-id",
  "provider": "server_or_vendor_contract",
  "capture_metadata": {
    "content_type": "image/jpeg",
    "capture_mode": "provider_defined"
  }
}
```

- Evidence transport: `TODO` — multipart upload, short-lived pre-signed upload, or vendor SDK token must be agreed. Do not base64 large images into ordinary JSON by default.
- Success `200`:

```json
{
  "face_verification_session_id": "face-session-id",
  "status": "verified",
  "expires_at": "2026-09-16T09:31:00Z"
}
```

- Validation/errors: `face_not_verified`, `liveness_failed`, `capture_quality_insufficient`, `challenge_expired`, `provider_unavailable`.
- Security: bind the session to employee, challenge, device, and tenant. Result must be short-lived and single-purpose. Define provider threat model and retention. Raw media is temporary on-device and never logged. A basic blink/turn flow is not described as strong liveness.

## 14. Submit attendance evidence

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `POST`
- URL: tenant API base + `/attendance/submit`
- Authentication: Bearer token plus registered-device signature when required
- Headers: `Idempotency-Key: <uuid>` recommended
- Request:

```json
{
  "challenge_id": "server-generated-id",
  "action": "attendance_event",
  "location": {
    "latitude": 34.1981,
    "longitude": 72.0478,
    "horizontal_accuracy": 8.4,
    "captured_at": "2026-09-16T09:30:25.200Z"
  },
  "device_key_id": "registered-key-id",
  "integrity_token": "opaque-platform-token",
  "device_signature": "base64url-signature",
  "face_verification_session_id": "face-session-id",
  "proximity_proof": null
}
```

- Boundary retry `409` or agreed non-success response:

```json
{
  "status": "location_retry_required",
  "location_outcome": "BOUNDARY_UNCERTAIN",
  "message": "Location accuracy is uncertain. Please remain on site while we obtain another location fix."
}
```

- Camera step-up `202`:

```json
{
  "status": "camera_verification_required",
  "camera_challenge_id": "camera-challenge-id",
  "expires_at": "2026-09-16T09:35:27Z",
  "message": "Additional on-site verification is required."
}
```

- Invisible corroboration success `200`:

```json
{
  "status": "accepted",
  "message": "Attendance marked successfully.",
  "server_time": "2026-09-16T09:30:27Z",
  "attendance_event_id": "event-id",
  "method": "mobile_face_geo",
  "camera_corroboration": "already_verified"
}
```

- Success `200`:

```json
{
  "status": "accepted",
  "message": "Attendance marked successfully.",
  "server_time": "2026-09-16T09:30:27Z",
  "attendance_event_id": "event-id",
  "method": "mobile_face_geo"
}
```

- Rejection `4xx` uses a stable code such as `outside_geofence`, `poor_location_accuracy`, `challenge_expired`, `challenge_already_used`, `device_not_registered`, `device_revoked`, `integrity_failed`, `face_not_verified`, `liveness_failed`, `proximity_required`, `proximity_failed`, `mobile_attendance_disabled`, or `outside_allowed_schedule`.
- Security: payload contains evidence, never client conclusions such as `verified` or `inside_geofence`. Laravel derives employee/tenant from auth and API context, verifies challenge freshness/use, integrity token and exact request hash, device signature, polygon location and accuracy against authoritative locations, face/liveness session, optional proximity proof, current policy, server time, schedule, and duplicates. The response must not disclose risk score, camera probability, internal anomaly signals, or random-selection criteria.

### Canonical payload and request hash

`TODO: BACKEND CONTRACT REQUIRED`

Before device-signing and Play Integrity work, mobile and Laravel must agree on:

- exact included fields and null handling
- UTF-8 encoding
- deterministic key ordering and number formatting (especially coordinates)
- timestamp format/time zone
- canonical JSON version identifier
- whether signature covers canonical bytes or their SHA-256 digest
- base64url padding rules and ECDSA signature encoding (DER vs IEEE P1363)

The Play Integrity `requestHash` should be SHA-256 over the agreed protected canonical data. Raw sensitive evidence is not placed directly in `requestHash`. The device signature may cover the same versioned canonical payload/digest. Unit-test vectors must be shared between Dart/Kotlin and Laravel.

## 15. Camera verification status

`TODO: BACKEND CONTRACT REQUIRED`

- Method: selected initial design `GET`; a push channel may replace polling later without changing the domain service
- URL: tenant API base + `/attendance/camera-verification/status?camera_challenge_id=<id>`
- Authentication: Bearer token
- Request: opaque camera challenge ID belonging to the current employee and attendance attempt
- Waiting `200`:

```json
{
  "status": "waiting_for_camera",
  "camera_challenge_id": "camera-challenge-id",
  "expires_at": "2026-09-16T09:35:27Z",
  "message": "Additional on-site verification is required."
}
```

- Verified `200`:

```json
{
  "status": "verified",
  "camera_challenge_id": "camera-challenge-id",
  "verified_at": "2026-09-16T09:32:12Z"
}
```

- Other employee-safe statuses: `pending`, `expired`, `failed`, `cancelled`, and `unavailable`.
- Validation/errors: `404 camera_challenge_not_found`; `403 camera_challenge_not_owned`; `429 polling_rate_limited`.
- Security: polling is read-only and idempotent and must never create duplicate challenges. The server returns no risk score, probability, signal weights, or selection reason. Laravel uses server time for expiry.

The server-side `CameraVerificationChallenge` stores its ID, attendance attempt/challenge, employee, required/expiry times, verification window, status, matched camera event/device, verification time, risk score at creation, and probability at creation. Those internal risk/probability fields are not serialized to the employee endpoint.

### Camera correlation and availability

Before returning a step-up instruction, Laravel searches existing Edge Agent/device attendance events in the configured time window for the same employee, tenant, supported registered camera, and applicable attendance location. A qualifying recent recognition produces invisible `already_verified` corroboration and does not inconvenience the employee. A recognition for another employee, an out-of-window event, or an unsupported/unmapped camera cannot satisfy the challenge.

If no applicable camera exists at the evaluated attendance location, Laravel must not create an impossible random challenge. It applies the tenant's configured fallback: accept normal secure mobile verification, require stronger mobile face/liveness, or send the attempt to administrator/manual review. Existing camera events remain in the central attendance-event pipeline; they are referenced rather than duplicated.

### Server-only adaptive selection and risk

Camera selection is unpredictable and server-side. The app does not know before submission whether step-up will be requested. Tenant-configurable initial defaults may use a 15% baseline, a temporary 5–10% floor after recent camera success, approximately 40–50% for medium risk, 70–80% for high risk, 100% for very high risk, and a roughly five-minute window. These are engineering defaults, not scientifically proven fraud probabilities.

Recent success can reduce probability temporarily but never to zero. A stronger current risk result overrides that reduction. The server uses a cryptographically secure random source after deterministic policy/risk calculation; deterministic probability logic is tested separately from random sampling.

`AttendanceRiskService` is a Laravel service, not a mobile service. It combines configurable weighted signals rather than treating one weak signal as proof. Signals may include new/replaced devices, repeated device changes, poor accuracy, polygon-boundary attempts, unusual location/travel, failed face/liveness, integrity concerns, rejected/rapid attempts, expired camera challenges, and other backend anomalies. Institutional Wi-Fi may be a positive/neutral signal; mobile data is neutral and never a rejection reason. Risk decays gradually across multiple clean events and never resets to minimum after one success. User-facing language says `risk`, `anomaly`, or `additional_verification_required`, never an accusation.

### Required Laravel tests

The backend suite must cover polygon point-inside behavior, accuracy overlap near a boundary, all three location outcomes, probability configuration, recent-success reduction, risk override, escalation and gradual decay, 100% very-high-risk selection, non-zero probability after success, camera-unavailable fallbacks, invisible recent-event corroboration, challenge creation/expiry, correct employee/device/location/time-window matching, rejection of another employee's event, duplicate event/idempotency behavior, and no duplicate challenge during repeated polling. Statistical tests use seeded/injected randomness and tolerances over adequate samples; they do not expect an exact count from a small sample.

## 16. Attendance history

`TODO: BACKEND CONTRACT REQUIRED`

- Method: proposed `GET`
- URL: tenant API base + `/attendance-history?cursor=<opaque>&limit=20`
- Authentication: Bearer token
- Request: query only; bounded `limit`, opaque cursor
- Success `200`:

```json
{
  "events": [
    {
      "attendance_event_id": "event-id",
      "server_time": "2026-09-16T09:30:27Z",
      "method": "mobile_face_geo",
      "status": "accepted",
      "location_name": "Administration Block"
    }
  ],
  "next_cursor": null
}
```

- Validation/errors: `422 invalid_cursor`; `401 unauthorized`.
- Security: employee receives only their own tenant-scoped history. Times and summarized statuses are server-produced; do not expose security verdict internals.

## Optional hardware proximity proof shape

`TODO: BACKEND CONTRACT REQUIRED`

BLE, NFC, UWB, and Wi-Fi RTT are optional future enhancements and are off by default. Standard secure mobile attendance must work without purchasing or installing any of them. Their cryptographic protocols are intentionally not invented here. An eventual `proximity_proof` must identify a versioned provider/protocol and be bound to organization, attendance location, short time window, and attendance challenge. A permanent beacon UUID/tag value is not sufficient. The phone must not need institution Wi-Fi, Edge Agent private-IP access, or local-LAN membership.

## Versioning and rollout questions

`TODO: BACKEND CONTRACT REQUIRED`

- Confirm API versioning strategy and minimum supported app version.
- Confirm central discovery ownership, DNS/certificate operations, URL allowlist domains, and organization-code rotation/recovery.
- Confirm Sanctum token/refresh/session behavior and device limits.
- Confirm device key algorithm, native attestation during registration, canonicalization, and shared test vectors.
- Confirm face/liveness provider, upload contract, data retention, and consent requirements.
- Confirm Play Integrity Cloud project, request-hash inputs, verdict policy, and server verification.
- Confirm whether any tenant opts into BLE/NFC/UWB/Wi-Fi RTT and then define that provider's rotating proof and hardware trust boundary.
- Confirm attendance method vocabulary (`mobile_face`, `mobile_geo`, `mobile_face_geo`, `mobile_high_security`, etc.) while keeping final classification server-side.
