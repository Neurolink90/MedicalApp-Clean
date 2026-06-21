# MediRecords Pro — PROJECT STATE
# Paste this at the start of EVERY Claude or Gemini session.
# Update it at the end of every session before closing the chat.

---

## Last Updated
Date: June 3, 2026
Last working session: Claude (Sonnet 4.6) — Phase 3 Medication Tracker

---

## Stack
- Frontend:     Flutter (PRIMARY TARGET = Android mobile)
- Auth:         Firebase Authentication (Email/Password)
- Database:     Firestore (persistent)
- Storage:      Firebase Storage
- Backend:      FastAPI (Python) on Render
- Backend URL:  https://medicalapp-clean.onrender.com
- FCM:          Firebase Cloud Messaging (push notifications)
- Package name: com.neurolink90.medirecords
- Test account: zach2@example.com (Firebase Auth + Firestore profile verified)

---

## 🔒 LOCKED FILES — DO NOT MODIFY WITHOUT CLAUDE REVIEW
  lib/medical_records_screen.dart              — dashboard with 3 action cards, drawer updated
  lib/login_screen.dart                        — Firebase Auth, AddPatientScreen, FCM static call
  lib/add_patient_screen.dart                  — Firebase Auth registration, Firestore profile
  lib/fcm_token_service.dart                   — NO dart:js, static methods, at lib/ ROOT
  lib/screens/document_list_screen.dart        — FAB upload, file_picker, QR signed URL
  lib/screens/audit_log_screen.dart            — Direct Firestore read, color-coded
  lib/screens/medication_tracker_screen.dart   — NEW: full medication CRUD + notifications
  backend/main.py                              — JSON+Form, Firestore only, no SQLite
  android/app/build.gradle.kts                 — namespace, desugaring, minSdk correct
  firestore.rules                              — ABAC + medications subcollection (REDEPLOY NEEDED)
  storage.rules                                — Backend-only Admin SDK lockdown (DEPLOYED)
  firebase.json                                — Merged Flutter + Rules config

---

## 🏆 MVP Loop — Phase 2 ✅ 100% COMPLETE
  ✅  Step 1: Login screen appears
  ✅  Step 2: Login → Patient Dashboard with dynamic greeting
  ✅  Step 3: Upload Record → file_picker grabs file
  ✅  Step 4: File appears in document list
  ✅  Step 5: QR icon → signed URL generated
  ✅  Step 6: Scan QR → URL active
  ✅  Step 7: Audit Trail from Firestore
  ✅  Step 8: Logout → session cleared

---

## File Registry
✅ Done  |  🔄 In Progress  |  ❌ Not Started  |  ⚠️ Broken

### Flutter Frontend (lib/)
  ✅  main.dart                                Keys in firebase_options.dart
  ✅  firebase_options.dart                    Generated via flutterfire configure
  ✅  login_screen.dart                        Firebase Auth, FCM, AddPatientScreen
  ✅  add_patient_screen.dart                  Firebase Auth registration
  ✅  medical_records_screen.dart              3 dashboard cards + drawer (updated)
  ✅  fcm_token_service.dart                   No dart:js, static, lib/ ROOT
  ✅  screens/document_list_screen.dart        Upload, list, QR — VERIFIED WORKING
  ✅  screens/audit_log_screen.dart            Firestore read — VERIFIED WORKING
  ✅  screens/medication_tracker_screen.dart   NEW — CRUD, reminders, audit log entries
  ✅  pubspec.yaml                             timezone ^0.9.4 added

### Android Config ✅ FULLY OPERATIONAL
  ✅  android/app/google-services.json
  ✅  android/app/build.gradle.kts
  ✅  MainActivity.kt

### Backend (backend/)
  ✅  main.py           Verified live — NEEDS /debug/* endpoints removed (Phase 3.5)
  ✅  requirements.txt

### Firebase (firebase/)
  ⚠️  firestore.rules   Updated with medications subcollection — NEEDS REDEPLOY
  ✅  storage.rules     Deployed live
  ✅  firebase.json

### Phase 3 Files
  ✅  screens/medication_tracker_screen.dart   BUILT
  ❌  services/biometric_service.dart          NOT STARTED
  ❌  screens/appointment_calendar_screen.dart NOT STARTED
  ❌  screens/emergency_qr_screen.dart         NOT STARTED

---

## ✅ Resolved Bugs — DO NOT REOPEN
1–30. [See previous entries — all resolved]
31. Medication subcollection missing from Firestore rules → added patients/{email}/medications/{medId}
32. timezone package missing for scheduled notifications → added timezone ^0.9.4 to pubspec.yaml

---

## ⚠️ IMMEDIATE ACTION REQUIRED
firestore.rules has been updated to include the medications subcollection.
You MUST redeploy before testing the medication tracker or it will fail silently.

Run this command:
  firebase deploy --only firestore:rules

---

## ⚠️ Active Task
Goal:    Integrate and test medication tracker
Steps:
  1. Run: flutter pub get  (picks up timezone ^0.9.4)
  2. Run: firebase deploy --only firestore:rules  (deploys medications subcollection rule)
  3. Run: flutter run -d emulator-5554
  4. Navigate to Medication Tracker from dashboard
  5. Add a test medication with a reminder time
  6. Confirm it appears in the list
  7. Check Firestore Console → patients/zach2@example.com/medications/

---

## Medication Tracker — Feature Summary
Location:    lib/screens/medication_tracker_screen.dart
Firestore:   patients/{email}/medications/{medId}
  Fields:    name, dosage, frequency, times[], instructions, isActive, startDate

Frequencies: Daily | Twice Daily | Three Times Daily | Weekly | As Needed
Reminders:   flutter_local_notifications + timezone — repeats daily at set times
Audit log:   ADD_MEDICATION | EDIT_MEDICATION | DELETE_MEDICATION written on each action
UI:          Active/Paused sections, switch to pause without deleting, edit dialog

---

## Next 3 Tasks (Priority Order)
1. flutter pub get → firebase deploy --only firestore:rules → flutter run → test tracker
2. UptimeRobot setup (uptimerobot.com → monitor https://medicalapp-clean.onrender.com/appointments every 5 min)
3. Test on physical Android device

---

## Upcoming Phase 3 Features (In Order)
  Next:    Appointment Calendar (table_calendar already in pubspec)
  Then:    Emergency Access QR (separate Firestore collection, public read)
  Then:    Biometric lock (local_auth already in pubspec)
  Then:    Remove /debug/* endpoints from backend/main.py
  Then:    Physical device FCM notification test

---

## Firestore Schema (Updated)
patients/{email}
  name, email, dob, status, created_at, fcm_token, last_updated

  patients/{email}/medications/{medId}   ← NEW subcollection
    name, dosage, frequency, times[], instructions, isActive, startDate

documents/{auto-id}
  patient_email, filename, file_type, upload_date, storage_path

audit_logs/{auto-id}  ← IMMUTABLE
  timestamp, user, action, file, details
  action values: UPLOAD_DOCUMENT | GENERATE_SHARE_QR | LOGIN |
                 ACCOUNT_CREATED | ADD_MEDICATION | EDIT_MEDICATION | DELETE_MEDICATION

---

## Render Backend
URL:      https://medicalapp-clean.onrender.com
⚠️ Free tier cold starts — UptimeRobot pending (do this today)
⚠️ /debug/db-check and /debug/seed-zach must be removed before launch

---

## Business Model (Decided)
Free:      5 documents, no QR sharing, 3 medications max
Personal:  $9.99/month — unlimited docs, QR, audit trail, medication tracker
Family:    $19.99/month — 5 profiles (Phase 4)
Pro:       $49.99/month — clinic dashboard (Phase 5)
Payments:  Stripe + Strike Lightning Network (Phase 4)

---

## Feature Roadmap (Post-MVP)
Phase 3 (now):
  ✅  Medication Tracker with reminders
  [ ] Appointment Calendar
  [ ] Emergency Access QR
  [ ] Biometric lock
  [ ] Remove /debug/* endpoints

Phase 4:
  [ ] AI personal health summary (document AI on uploaded PDFs)
  [ ] Family account management
  [ ] Provider portal (web app)
  [ ] Stripe + Strike payments

Phase 5:
  [ ] Wearable integration (Apple Health / Google Fit)
  [ ] Anonymized aggregate insights (opt-in, de-identified)
  [ ] Telemedicine integration
  [ ] Insurance card scanner

---

## Phase Checklist

### Phase 1 ✅ COMPLETE
### Phase 2 ✅ COMPLETE

### Phase 3 — Hardening 🔄 IN PROGRESS
  [x] Medication Tracker built (CRUD + local notifications + audit log)
  [ ] flutter pub get + firebase deploy --only firestore:rules ← DO NOW
  [ ] Medication tracker tested on emulator
  [ ] UptimeRobot ping configured (uptimerobot.com, 5-min interval)
  [ ] Appointment Calendar screen built
  [ ] Emergency Access QR screen built
  [ ] Biometric lock (local_auth) implemented
  [ ] Physical Android device test
  [ ] FCM push notifications verified on physical device
  [ ] /debug/* endpoints removed from backend/main.py
  [ ] PDF generation before upload

### Phase 4 — Payments ❌ NOT STARTED
  [ ] Stripe Cloud Function (Node.js)
  [ ] Strike Lightning Network
  [ ] Payment webhook → Firestore status
  [ ] Record access gated on payment

### Phase 5 — Pre-Flight ❌ NOT STARTED
  [ ] HIPAA audit
  [ ] Firebase BAA signed with Google
  [ ] Healthcare attorney review (~$2–5K)
  [ ] Play Store submission prep
  [ ] All /debug/* endpoints removed
