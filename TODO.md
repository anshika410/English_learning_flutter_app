# Ella — TODO

## Flutter App (handle later)

- [ ] **Auto re-auth on 401** — Add HTTP interceptor that catches 401, calls `POST /auth/anonymous` with same `device_id`, gets new token, retries the original request. User should never see an error screen when token expires.

## Backend (future)

- [ ] **Non-linear skill targeting** — Replace linear unit progression with weighted scoring (days_since_seen, failed attempts, interest match, spaced repetition). Pick top 3-4 skills regardless of unit order.
- [ ] **GET /curriculum endpoint** — Return full skill ID→name mapping per level. Useful if Flutter app needs it server-side instead of hardcoded.

## Simulator (low priority)

- [ ] Auto re-auth on 401 in simulator's `callEllaAPI` (currently user must click Reset)
