# MedicalApp-Clean (MediRecords Pro)

## Project Overview
A cross-platform mobile application built with **Flutter** and powered by a **Flask (Python)** backend. This app allows medical professionals to securely log in and manage patient records, including names, medical history, and other health data. Designed for Android and iOS, the app provides a clean UI, backend integration, and real-time communication features.

## Tech Stack
* **Frontend:** Flutter (Dart)
    * **Packages:** `http`, `table_calendar`, `url_launcher`, `shared_preferences`
    * **Deployment:** GitHub Pages (Web), Android, iOS
* **Backend:** Python (Flask)
    * **Key Libraries:** `flask`, `flask-cors`, `reportlab` (PDF generation), `cryptography`
    * **Deployment:** Render (Web Service)
    * **Data Source:** `medical_code_library.py` (Mock Data / In-Memory Class Structures)

## Development Workflow

### Backend (Python)
* **Entry Point:** `backend.py`
* **Install Dependencies:** `pip install -r requirements.txt`
* **Run Locally:** `python backend.py` (Runs on `http://127.0.0.1:5000`)
* **Run Tests:** `python test_backend.py`
* **Key Routes:**
    * `POST /login`: Authenticates users.
    * `POST /forgot-password`: Generates reset PDF and mocks email sending.
    * `GET /download-instructions`: Serves the generated PDF file.
    * `GET /patients`: Returns JSON list of patient records.

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
    * **Security:** Never store plain-text passwords in production. Use hashed credentials (currently mocked in `backend.py`).
2.  **State Management:**
    * Use `setState` for simple UI state (loading spinners, form toggles).
    * Use `FutureBuilder` or `async/await` patterns for network calls.
3.  **Backend & PDF Logic:**
    * PDFs are generated using **ReportLab** on the backend, not the frontend.
    * The frontend uses `url_launcher` to open the `/download-instructions` endpoint.
4.  **Deployment:**
    * **Render:** Automatically deploys from the `main` branch.
    * **GitHub Pages:** Must be manually deployed using the `peanut` command sequence above.

## Directory Structure
* `/`: Root (Backend code, git config, requirements)
* `/lib`: Flutter source code
    * `main.dart`: App entry point
    * `login_screen.dart`: Auth UI + Password Reset logic
    * `medical_records_screen.dart`: Patient list + Logout
    * `password_update_screen.dart`: Form for new password entry
* `/assets`: Static files (images, configs)