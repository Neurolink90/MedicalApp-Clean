import os
import io
import json
import base64
import logging
import sqlite3
from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, Form, HTTPException, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials, messaging
from cryptography.fernet import Fernet
import bcrypt

# --- INITIALIZATION ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="MediRecords Pro Unified Backend")
DB_NAME = "medical_app.db"

# --- BCRYPT PASSWORD HELPERS ---
def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def verify_password(password: str, hashed: str) -> bool:
    return bcrypt.checkpw(password.encode('utf-8'), hashed.encode('utf-8'))

# --- ENCRYPTION SETUP ---
FERNET_KEY = os.environ.get('FERNET_KEY', 'mL-N5Npl_dijvORR5c4im7nWs5HydjW_qXCbVFKFGKk=')
cipher = Fernet(FERNET_KEY.encode())

# --- CORS SETUP ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://neurolink90.github.io", "http://localhost:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- FIREBASE ADMIN SDK ---
try:
    if not firebase_admin._apps:
        firebase_b64 = os.getenv("FIREBASE_CONFIG_JSON")
        if firebase_b64:
            decoded_bytes = base64.b64decode(firebase_b64.strip())
            firebase_info = json.loads(decoded_bytes.decode('utf-8'))
            cred = credentials.Certificate(firebase_info)
            firebase_admin.initialize_app(cred)
            logger.info("✅ Firebase Admin initialized successfully from Base64!")
except Exception as e:
    logger.error(f"❌ Firebase Init Error: {e}")

# --- DATABASE LOGIC ---
def get_db():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('''CREATE TABLE IF NOT EXISTS patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT, dob TEXT, ssn TEXT, address TEXT, 
        email TEXT UNIQUE NOT NULL, phone TEXT, 
        password TEXT NOT NULL, fcm_token TEXT)''')
    cursor.execute('CREATE TABLE IF NOT EXISTS medications (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, name TEXT, dosage TEXT, frequency TEXT, reminder_time TEXT)')
    cursor.execute('CREATE TABLE IF NOT EXISTS vitals (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, type TEXT, value TEXT, unit TEXT, timestamp TEXT)')
    cursor.execute('CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, filename TEXT, file_type TEXT, upload_date TEXT, file_data BLOB)')
    
    # Seed Zach's Record
    cursor.execute('SELECT * FROM patients WHERE email = ?', ("zach@example.com",))
    if not cursor.fetchone():
        hashed_pw = hash_password("helloandgoodbye0")
        encrypted_ssn = cipher.encrypt("000-00-0000".encode()).decode()
        cursor.execute('''INSERT INTO patients (name, email, password, dob, ssn, address, phone) 
                          VALUES (?, ?, ?, ?, ?, ?, ?)''',
                       ("Zach SQLite", "zach@example.com", hashed_pw, "1980-01-01", encrypted_ssn, "123 Main St", "555-1234"))
    conn.commit()
    conn.close()

init_db()

# --- AUTH & TOKEN ---

@app.post("/login")
async def login(email: str = Form(...), password: str = Form(...)):
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (email,)).fetchone()
    conn.close()
    if user and verify_password(password, user['password']):
        return {"success": True, "email": user['email']}
    raise HTTPException(status_code=401, detail="Invalid Credentials")

@app.post("/register-token")
@app.post("/update-fcm-token") # Handle both endpoint names used by the app
async def register_token(user_id: str = Form(...), fcm_token: str = Form(...)):
    conn = get_db()
    conn.execute('UPDATE patients SET fcm_token = ? WHERE email = ?', (fcm_token, user_id))
    conn.commit()
    conn.close()
    logger.info(f"🚀 Token updated for {user_id}")
    return {"status": "success"}

# --- DATA FETCHING (Clears the 404s/405s) ---

@app.get("/patients")
async def get_patients():
    conn = get_db()
    users = conn.execute('SELECT name, dob, email FROM patients').fetchall()
    conn.close()
    return [{"name": u['name'], "dob": u['dob'], "email": u['email'], "status": "Stable", "mrn": "MRN-0000"} for u in users]

@app.get("/profile")
async def get_profile(email: str = "zach@example.com"): # Default value fixes 422 error
    conn = get_db()
    user = conn.execute('SELECT name, email, dob, address, phone FROM patients WHERE email = ?', (email,)).fetchone()
    conn.close()
    if user: return dict(user)
    raise HTTPException(status_code=404, detail="Profile not found")

@app.get("/medications")
async def get_medications(email: str = "zach@example.com"):
    conn = get_db()
    meds = conn.execute('SELECT name, dosage, frequency, reminder_time FROM medications WHERE patient_email = ?', (email,)).fetchall()
    conn.close()
    return [dict(m) for m in meds]

@app.get("/vitals")
async def get_vitals_list(email: str = "zach@example.com"):
    conn = get_db()
    v = conn.execute('SELECT type, value, unit, timestamp FROM vitals WHERE patient_email = ?', (email,)).fetchall()
    conn.close()
    return [dict(row) for row in v]

@app.get("/documents")
async def get_documents_list(email: str = "zach@example.com"):
    conn = get_db()
    docs = conn.execute('SELECT filename, file_type, upload_date FROM documents WHERE patient_email = ?', (email,)).fetchall()
    conn.close()
    return [dict(row) for row in docs]

@app.get("/appointments")
async def get_appointments(email: str = "zach@example.com"):
    return [{"date": "2026-05-10", "time": "10:00 AM", "provider": "Dr. Smith", "type": "Checkup"}]

# --- DATA SAVING ---

@app.post("/vitals")
async def add_vitals(email: str = Form(...), type: str = Form(...), value: str = Form(...), unit: str = Form(...)):
    conn = get_db()
    conn.execute('INSERT INTO vitals (patient_email, type, value, unit, timestamp) VALUES (?, ?, ?, ?, ?)',
                 (email, type, value, unit, datetime.now().strftime('%Y-%m-%d %H:%M')))
    conn.commit()
    conn.close()
    return {"success": True}

@app.post("/documents/upload")
async def upload_document(email: str = Form(...), file: UploadFile = File(...)):
    file_data = await file.read()
    conn = get_db()
    conn.execute('INSERT INTO documents (patient_email, filename, file_type, upload_date, file_data) VALUES (?, ?, ?, ?, ?)',
                 (email, file.filename, file.content_type, datetime.now().strftime('%Y-%m-%d'), file_data))
    conn.commit()
    
    user = conn.execute('SELECT fcm_token FROM patients WHERE email = ?', (email,)).fetchone()
    conn.close()
    
    if user and user['fcm_token']:
        try:
            message = messaging.Message(
                notification=messaging.Notification(title="New Record", body=f"Document '{file.filename}' added."),
                token=user['fcm_token']
            )
            messaging.send(message)
        except Exception as e:
            logger.error(f"FCM Notification Failed: {e}")

    return {"success": True}

@app.get("/debug/db-check")
async def db_check():
    conn = get_db()
    user = conn.execute('SELECT email, fcm_token FROM patients WHERE email = ?', ("zach@example.com",)).fetchone()
    conn.close()
    return {"zach_record": dict(user) if user else "Not Found"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))