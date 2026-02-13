from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import sqlite3
import os
import io
import logging
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

app = Flask(__name__)

# UPDATED CORS: Explicitly allows your GitHub Pages site to send files and data
CORS(app, resources={r"/*": {"origins": ["https://neurolink90.github.io", "http://localhost:*"]}})

logging.basicConfig(level=logging.INFO)
DB_NAME = "medical_app.db"

# --- DATABASE HELPERS ---

def get_db():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()
    # 1. Patients Table
    cursor.execute('CREATE TABLE IF NOT EXISTS patients (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, dob TEXT, ssn TEXT, address TEXT, email TEXT UNIQUE NOT NULL, phone TEXT, password TEXT NOT NULL)')
    # 2. Medications Table
    cursor.execute('CREATE TABLE IF NOT EXISTS medications (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, name TEXT, dosage TEXT, frequency TEXT, reminder_time TEXT)')
    # 3. Vitals Table
    cursor.execute('CREATE TABLE IF NOT EXISTS vitals (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, type TEXT, value TEXT, unit TEXT, timestamp TEXT)')
    # 4. Documents Table (for BLOB storage)
    cursor.execute('CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, filename TEXT, file_type TEXT, upload_date TEXT, file_data BLOB)')
    # 5. Medical Records (for Calendar/Appointments)
    cursor.execute('CREATE TABLE IF NOT EXISTS medical_records (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, date TEXT, provider TEXT, specialty TEXT, content TEXT)')
    
    conn.commit()
    conn.close()

init_db()

# --- AUTH & REGISTRATION ---

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    hashed_pw = generate_password_hash(data.get('password'))
    conn = get_db()
    try:
        conn.execute('INSERT INTO patients (name, email, password, dob) VALUES (?, ?, ?, ?)', 
                     (data.get('name'), data.get('email'), hashed_pw, data.get('dob', '1980-01-01')))
        conn.commit()
        return jsonify(success=True)
    except:
        return jsonify(success=False, message="User already exists"), 400
    finally:
        conn.close()

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (data.get('email'),)).fetchone()
    conn.close()
    if user and check_password_hash(user['password'], data.get('password')):
        return jsonify(success=True, email=user['email'])
    return jsonify(success=False), 401

# --- PROFILE & APPOINTMENTS ---

@app.route('/profile', methods=['GET', 'POST'])
def handle_profile():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    if request.method == 'GET':
        user = conn.execute('SELECT * FROM patients WHERE email = ?', (email,)).fetchone()
        conn.close()
        if user:
            return jsonify({"name": user['name'], "address": user['address'], "phone": user['phone'], "email": user['email'], "dob": user['dob']})
        return jsonify(message="User not found"), 404
    else:
        data = request.get_json()
        conn.execute('UPDATE patients SET name=?, address=?, phone=? WHERE email=?', (data['name'], data['address'], data['phone'], email))
        conn.commit()
        conn.close()
        return jsonify(success=True)

@app.route('/appointments', methods=['GET'])
def get_appointments():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    records = conn.execute('SELECT * FROM medical_records WHERE patient_email = ?', (email,)).fetchall()
    conn.close()
    formatted = {}
    for r in records:
        date_key = f"{r['date']}T00:00:00Z"
        if date_key not in formatted: formatted[date_key] = []
        formatted[date_key].append({'title': f"{r['provider']} - {r['specialty']}", 'type': 'appointment'})
    return jsonify(formatted)

# --- TRACKERS (MEDS & VITALS) ---

@app.route('/medications', methods=['GET', 'POST'])
def handle_medications():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    if request.method == 'GET':
        meds = conn.execute('SELECT * FROM medications WHERE patient_email = ?', (email,)).fetchall()
        conn.close()
        return jsonify([dict(m) for m in meds])
    else:
        data = request.get_json()
        conn.execute('INSERT INTO medications (patient_email, name, dosage, frequency, reminder_time) VALUES (?, ?, ?, ?, ?)',
                     (email, data['name'], data['dosage'], data['frequency'], data['reminder_time']))
        conn.commit()
        conn.close()
        return jsonify(success=True)

@app.route('/vitals', methods=['GET', 'POST'])
def handle_vitals():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    if request.method == 'GET':
        vitals = conn.execute('SELECT * FROM vitals WHERE patient_email = ? ORDER BY timestamp DESC', (email,)).fetchall()
        conn.close()
        return jsonify([dict(v) for v in vitals])
    else:
        data = request.get_json()
        conn.execute('INSERT INTO vitals (patient_email, type, value, unit, timestamp) VALUES (?, ?, ?, ?, ?)',
                     (email, data['type'], data['value'], data['unit'], datetime.now().strftime('%Y-%m-%d %H:%M')))
        conn.commit()
        conn.close()
        return jsonify(success=True)

# --- DOCUMENTS (FIXED UPLOAD) ---

@app.route('/documents/upload', methods=['POST'])
def upload_document():
    file = request.files.get('file')
    email = request.form.get('email', 'zach@example.com')
    if file:
        file_data = file.read()
        conn = get_db()
        conn.execute('INSERT INTO documents (patient_email, filename, file_type, upload_date, file_data) VALUES (?, ?, ?, ?, ?)',
                     (email, file.filename, file.content_type, datetime.now().strftime('%Y-%m-%d'), file_data))
        conn.commit()
        conn.close()
        return jsonify(success=True)
    return jsonify(success=False), 400

@app.route('/documents', methods=['GET'])
def get_documents():
    email = request.args.get('email', 'zach@example.com')
    conn = get_db()
    docs = conn.execute('SELECT id, filename, upload_date FROM documents WHERE patient_email = ?', (email,)).fetchall()
    conn.close()
    return jsonify([dict(doc) for doc in docs])

# --- NEW: PROVIDER DASHBOARD ---

@app.route('/provider/dashboard', methods=['GET'])
def provider_dashboard():
    conn = get_db()
    # Pulls all patients and their latest recorded Blood Pressure
    summary = conn.execute('''
        SELECT p.name, p.email, p.dob, 
        (SELECT value FROM vitals WHERE patient_email = p.email AND type = 'Blood Pressure' ORDER BY timestamp DESC LIMIT 1) as last_bp
        FROM patients p
    ''').fetchall()
    conn.close()
    return jsonify([dict(row) for row in summary])

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))