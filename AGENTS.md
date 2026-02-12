# MedicalApp-Clean (MediRecords Pro)

## Project Overview
A cross-platform mobile application built with **Flutter** and powered by a **Flask (Python)** backend. This app allows medical professionals to securely log in and manage patient records, including names, medical history, and other health data. Designed for Android and iOS, the app provides a clean UI, backend integration, and real-time communication features.

## Tech Stack
* **Frontend:** Flutter (Dart)
    * **Packages:** `http`, `table_calendar`, `url_launcher`, `shared_preferences`
    * **Deployment:** GitHub Pages (Web), Android, iOS
* **Backend:** Python (Flask)
    * **Database:** SQLite (`medical_app.db`) - **NEW**
    * **Key Libraries:** `flask`, `flask-cors`, `reportlab` (PDF generation), `sqlite3` (Built-in)
    * **Deployment:** Render (Web Service)

## Development Workflow

### Backend (Python)
* **Entry Point:** `backend.py`
* **Data Source:** SQLite Database. Tables: `patients`, `medical_records`.
    * *Note:* The database is auto-initialized with a demo user (`john@example.com`) on server start if it doesn't exist.
* **Install Dependencies:** `pip install -r requirements.txt`
* **Run Locally:** `python backend.py` (Runs on `http://127.0.0.1:5000`)
* **Run Tests:** `python test_backend.py`
* **Key Routes:**
    * `POST /login`: Authenticates users against the `patients` table.
    * `GET /profile` & `POST /profile`: Reads/Writes user details to the DB.
    * `GET /download-instructions`: Generates and serves PDF files.
    * `GET /patients`: Returns JSON list of patient records from DB.

### Frontend (Flutter)
* **Entry Point:** `lib/main.dart`
* **Install Dependencies:** `flutter pub get`
* **Run Locally:** `flutter run`
* **Build for Web (GitHub Pages):**
    ```bash
    flutter pub global run peanut --extra-args "--base-href=/MedicalApp-Clean/"
    git push origin gh-pages --force
    ```

## Project Rules & Conventions
1.  **Authentication:**
    * **Demo User:** Email: `john@example.com` / Password: `securepassword`
    * **Security:** User data is stored in SQLite. Passwords currently plain-text (Future: Implement Hashing).
2.  **State Management:**
    * Use `setState` for simple UI state.
    * Use `FutureBuilder` or `async/await` patterns for API calls.
3.  **Data Handling:**
    * **Frontend:** Must handle JSON decoding carefully.
    * **Backend:** Must sanitize data (convert bytes to string) before sending JSON to prevent serialization errors.
4.  **Deployment:**
    * **Render:** Automatically deploys from the `main` branch.
    * **GitHub Pages:** Must be manually deployed using the `peanut` command sequence above.

## Directory Structure
* `/`: Root (Backend code, git config, requirements)
* `/lib`: Flutter source code
    * `main.dart`: App entry point
    * `login_screen.dart`: Auth UI + Password Reset logic
    * `medical_records_screen.dart`: Patient list + Logout + Profile Nav
    * `profile_screen.dart`: User details form (Name, Address, Phone)
    * `password_update_screen.dart`: Form for new password entry
* `/assets`: Static files (images, configs)