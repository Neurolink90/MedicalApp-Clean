from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import sqlite3
import os
import io
import logging
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime

app = Flask(__name__)
CORS(app)

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
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS patients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            dob TEXT,
            ssn TEXT,
            address TEXT,
            email TEXT UNIQUE NOT NULL,
            phone TEXT,
            password TEXT NOT NULL
        )
    ''')

    # 2. Medical Records Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS medical_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_email TEXT NOT NULL,
            date TEXT,
            provider TEXT,
            specialty TEXT,
            content TEXT,
            FOREIGN KEY(patient_email) REFERENCES patients(email)
        )
    ''')
    
    # 3. Documents Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_email TEXT NOT NULL,
            filename TEXT NOT NULL,
            file_type TEXT,
            upload_date TEXT,
            file_data BLOB,
            FOREIGN KEY(patient_email) REFERENCES patients(email)
        )
    ''')
    
    conn.commit()
    conn.close()

init_db()

# --- ROUTES ---

@app.route("/")
def health_check():
    return jsonify({"status": "healthy"})

# --- PHASE 1: NEW REGISTER ROUTE ---
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    name = data.get('name')
    email = data.get('email')
    password = data.get('password')
    dob = data.get('dob', '1990-01-01')

    if not email or not password:
        return jsonify(success=False, message="Email and Password required"), 400

    hashed_pw = generate_password_hash(password)
    
    conn = get_db()
    try:
        conn.execute('''
            INSERT INTO patients (name, email, password, dob)
            VALUES (?, ?, ?, ?)
        ''', (name, email, hashed_pw, dob))
        conn.commit()
        return jsonify(success=True, message="User registered successfully!")
    except sqlite3.IntegrityError:
        return jsonify(success=False, message="Email already exists"), 400
    finally:
        conn.close()

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (email,)).fetchone()
    conn.close()

    if user and check_password_hash(user['password'], password):
        return jsonify(success=True, message="Login successful", user_email=email)
    return jsonify(success=False, message="Invalid credentials"), 401

@app.route('/patients', methods=['GET'])
def get_patients():
    conn = get_db()
    users = conn.execute('SELECT name, dob, ssn, email FROM patients').fetchall()
    conn.close()
    
    patient_list = []
    for user in users:
        ssn_val = user['ssn'] if user['ssn'] else "000-00-0000"
        patient_list.append({
            "name": user['name'],
            "dob": user['dob'],
            "mrn": f"MRN-{ssn_val[-4:]}",
            "status": "Stable",
            "email": user['email']
        })
    return jsonify(patient_list)

@app.route('/profile', methods=['GET'])
def get_profile():
    email = request.args.get('email', 'john@example.com')
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (email,)).fetchone()
    conn.close()
    if user:
        return jsonify({
            "name": user['name'], "address": user['address'],
            "phone": user['phone'], "email": user['email'], "dob": user['dob']
        })
    return jsonify(message="User not found"), 404

@app.route('/profile', methods=['POST'])
def update_profile():
    data = request.get_json()
    email = data.get('email', 'john@example.com')
    
    conn = get_db()
    try:
        conn.execute('''
            UPDATE patients SET name=?, address=?, phone=? WHERE email=?
        ''', (data['name'], data['address'], data['phone'], email))
        conn.commit()
        return jsonify(success=True)
    except Exception as e:
        return jsonify(success=False, message=str(e)), 500
    finally:
        conn.close()

@app.route('/appointments', methods=['GET'])
def get_appointments():
    email = request.args.get('email', 'john@example.com')
    conn = get_db()
    records = conn.execute('SELECT * FROM medical_records WHERE patient_email = ?', (email,)).fetchall()
    conn.close()

    formatted_events = {}
    for record in records:
        date_key = f"{record['date']}T00:00:00Z"
        if date_key not in formatted_events: formatted_events[date_key] = []
        formatted_events[date_key].append({'title': f"{record['provider']} - {record['specialty']}", 'type': 'appointment'})
    return jsonify(formatted_events)

@app.route('/documents/upload', methods=['POST'])
def upload_document():
    file = request.files.get('file')
    email = request.form.get('email', 'john@example.com')
    if file:
        conn = get_db()
        conn.execute('INSERT INTO documents (patient_email, filename, file_type, upload_date, file_data) VALUES (?, ?, ?, ?, ?)',
                     (email, file.filename, file.content_type, datetime.now().strftime('%Y-%m-%d'), file.read()))
        conn.commit()
        conn.close()
        return jsonify(success=True)
    return jsonify(success=False), 400

@app.route('/documents', methods=['GET'])
def get_documents():
    email = request.args.get('email', 'john@example.com')
    conn = get_db()
    docs = conn.execute('SELECT id, filename, upload_date FROM documents WHERE patient_email = ?', (email,)).fetchall()
    conn.close()
    return jsonify([{"id": d['id'], "filename": d['filename'], "date": d['upload_date']} for d in docs])

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))