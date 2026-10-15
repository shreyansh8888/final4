# Firebase Configuration & Architecture Guide

Firebase Authentication, Firestore, and Cloud Storage are wired into `Garba AI`. All operations flow through `lib/core/services/firebase_service.dart` with state management handled via Riverpod (`auth_provider.dart`, `events_provider.dart`, `booking_provider.dart`).

---

## 1. Firebase Authentication

The app supports two authentication providers:

### A. Email & Password Authentication
- Registration with full name, email, password, and optional phone.
- Sends an email verification link via `user.sendEmailVerification()`.
- Routes newly registered users to `/verify-email`.
- Password reset emails sent via `FirebaseAuth.instance.sendPasswordResetEmail()`.
- Account deletion supported with security re-auth checks.

### B. Phone Number Authentication (OTP)
- Real Firebase Phone Authentication using `FirebaseAuth.instance.verifyPhoneNumber`.
- E.164 phone formatting (auto-prepends `+91` if omitted).
- Automatic SMS retrieval / credential verification on supported Android devices.
- 6-digit OTP verification via `PhoneAuthProvider.credential(...)` and `signInWithCredential(...)`.
- `authProvider` listens to `FirebaseAuth.instance.authStateChanges()` to automatically update user state.

---

## 2. Firestore Event Management

Garba events are stored in the Firestore `events` collection:
- **Public Read**: Anyone can browse Garba events with names, photos, venues, dates, timings, ticket prices, and available seats.
- **Filtering**: Real-time filtering by category (Navratri, Dandiya, Cultural, Workshop) and keyword search.
- **Resilience**: The app includes default Garba festival seed events if Firestore is initially empty or offline.
- **Admin Management**: Administrators can create, edit, and delete events directly from the in-app Admin Console.

---

## 3. Ticket Booking & Idempotency

Booking tickets updates Firestore atomically:
- **Duplicate Prevention**: In-memory and state-level mutex prevents duplicate bookings from rapid button taps.
- **Atomic Capacity Tracking**: When a ticket is booked, the event's `booked_count` is incremented. If `booked_count >= capacity`, the event transitions to sold out.
- **Firestore `bookings` Collection**: Saves ticket record with:
  - `id`: Unique booking identifier (e.g., `BK-2026-XXXX`).
  - `user_id`: Attendee's Firebase Auth UID.
  - `event_id`: Selected Garba event ID.
  - `ticket_uuid`: Unique UUID (`v4`).
  - `qr_data`: Digitally signed JSON payload.
  - `booking_date`: Timestamp.
  - `status`: `'confirmed'` | `'cancelled'`.
- **User Booking History**: `myBookingsProvider` queries Firestore for all bookings where `user_id == currentUserId`.
- **Cancellation**: Attendees can cancel confirmed tickets, freeing up the seat in Firestore.

---

## 4. QR Code Digital Passes & Production Validation

The ticket screen renders a scannable QR code generated from `booking.qrData`.

> [!IMPORTANT]
> **Production QR Validation Protocol:**
> A QR code displayed on a user's device cannot be treated as sole proof of admission without server-side validation:
> 1. **Cryptographic Signature Verification**: The gate scanner app verifies the digital signature (HMAC-SHA256 or ECDSA) within the QR payload against the backend key to prevent counterfeit QR generation.
> 2. **One-Time Admission State**: Upon scanning, the gate scanner queries Firestore to verify `status == 'confirmed'` and atomically updates `status` to `'admitted'` (`checked_in`). Any subsequent scan of the same QR code will be rejected as already admitted (preventing duplicate entry from screenshots).
> 3. **Identity Verification**: The gate operator checks the attendee's government-issued photo ID against `user_name` on the ticket.
> 4. **Entry Time Window**: Validates that the scan timestamp falls within the event's door-opening window.

---

## 5. Administrative Controls & Firestore Security

Admin operations are protected at multiple layers:
1. **Firestore Security Rules (`firestore.rules`)**:
   - Write operations on `events` and read operations on all user bookings require admin privileges.
   - Admin authorization rule:
     ```javascript
     function isAdmin() {
       return request.auth != null && (
         request.auth.token.admin == true ||
         request.auth.token.email == 'admin@garba.com' ||
         request.auth.token.email.matches('.*admin.*') ||
         (exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
          get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true)
       );
     }
     ```
2. **GoRouter Route Guard (`app_router.dart`)**:
   - Navigation to `/admin` or `/admin/*` redirects non-admin users to `/home`.
3. **Service Layer Guard (`firebase_service.dart`)**:
   - `createEvent`, `updateEvent`, `deleteEvent`, and `getAllBookings` assert admin authorization before executing requests.

---

## 6. How to Grant Admin Role in Firebase

To grant administrative access to a user:
1. **Option A (Email rule)**: Register or sign in with an email containing `admin` (e.g. `admin@garba.com`).
2. **Option B (Firestore document)**: In the Firebase Console → Firestore Database → `users` collection → create or edit document with ID equal to the user's UID, setting `isAdmin: true`.
3. **Option C (Custom Claims via Firebase Admin SDK)**:
   ```javascript
   await admin.auth().setCustomUserClaims(uid, { admin: true });
   ```

---

## 7. REQUIRED one-time setup after this update

### A. Publish the new Firestore rules (bookings / sessions / leaderboard)
Firebase Console → Firestore Database → Rules → paste `firestore.rules` → **Publish**
(or `firebase deploy --only firestore:rules`). Without this, saving bookings,
practice sessions and the leaderboard is rejected.

### B. Phone (OTP) sign-in
1. Authentication → Sign-in method → enable **Phone**.
2. Project settings → Your apps → Android (`com.example.garba_app`) → **Add fingerprint**, add BOTH:
   - SHA-1:   `40:EC:B3:60:F0:8E:B2:38:67:35:F9:FE:FA:7E:15:FA:72:B3:EB:DD`
   - SHA-256: `74:D9:4D:1D:A0:79:5A:7C:44:D7:0F:5C:C8:32:E9:01:29:3C:62:CF:7A:47:7D:83:96:45:CE:13:AB:09:72:B6`
   (they belong to `android/app/garba_debug.keystore`, which every build now uses, so they never change)
3. **Download the new `google-services.json`** and replace `android/app/google-services.json`
   (the old one has an empty `oauth_client` list, which is why phone auth failed).
4. Google Cloud Console → APIs & Services → enable **Android Device Verification / Play Integrity API** if prompted.
5. Rebuild and install the APK.

### C. Sample events
Sign in once with an admin account and open the Events tab; the sample events are
uploaded to Firestore so their seat counts become permanent.
