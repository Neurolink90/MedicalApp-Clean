from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import sqlite3
import os
import logging
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash  # <--- SECURITY UPGRADE

app = Flask(__name__)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
DB_NAME = "medical_app.db"

# --- DATABASE HELPERS ---

def get_db():
    """Connect to the SQLite database."""
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    """Initialize the database with tables and a demo user."""
    conn = get_db()
    cursor = conn.cursor()
    
    # 1. Create Patients Table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS patients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            dob TEXT,
            ssn TEXT UNIQUE,
            address TEXT,
            email TEXT UNIQUE NOT NULL,
            phone TEXT,
            password TEXT NOT NULL
        )
    ''')

    # 2. Create Medical Records Table
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
    
    conn.commit()
    
    # 3. Seed Demo User (John Doe) if he doesn't exist
    cursor.execute('SELECT * FROM patients WHERE email = ?', ("john@example.com",))
    if not cursor.fetchone():
        app.logger.info("Seeding demo user: John Doe")
        # SECURITY: Hash the password before saving!
        hashed_pw = generate_password_hash("securepassword")
        
        cursor.execute('''
            INSERT INTO patients (name, dob, ssn, address, email, phone, password)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', ("John Doe", "1980-01-01", "123-45-6789", "123 Main St", "john@example.com", "555-1234", hashed_pw))
        
        # Seed Records
        cursor.execute('INSERT INTO medical_records (patient_email, date, provider, specialty, content) VALUES (?, ?, ?, ?, ?)',
                       ("john@example.com", "2026-02-10", "Dr. Smith", "Cardiology", "Follow-up on heart rate"))
        cursor.execute('INSERT INTO medical_records (patient_email, date, provider, specialty, content) VALUES (?, ?, ?, ?, ?)',
                       ("john@example.com", "2026-02-15", "LabCorp", "Diagnostics", "Blood work panel"))
        conn.commit()
    
    conn.close()

# Initialize DB on startup
init_db()

# --- HELPER: Fixes the "Bytes" Error ---
def clean_text(value):
    """Converts bytes to string if needed, preventing JSON errors."""
    if isinstance(value, bytes):
        return value.decode('utf-8')
    return str(value) if value else ""

# --- PDF GENERATOR HELPER ---
def create_reset_pdf(filename, user_email):
    c = canvas.Canvas(filename, pagesize=letter)
    c.drawString(100, 750, "MediRecords Pro - Security Alert")
    c.drawString(100, 730, "------------------------------------------------")
    c.drawString(100, 700, f"Password reset requested for: {user_email}")
    c.drawString(100, 680, "Your temporary reset code is: 123456")
    c.save()

# --- ROUTES ---

@app.route("/")
def health_check():
    return jsonify({"status": "healthy"})

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    email = data.get('email')
    password = data.get('password')
    
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (email,)).fetchone()
    conn.close()

    # SECURITY: Verify the hash instead of plain text
    if user and check_password_hash(user['password'], password):
        return jsonify(success=True, message="Login successful")
    
    return jsonify(success=False, message="Invalid credentials"), 401

@app.route('/profile', methods=['GET'])
def get_profile():
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', ("john@example.com",)).fetchone()
    conn.close()

    if user:
        return jsonify({
            "name": clean_text(user['name']),
            "address": clean_text(user['address']),
            "phone": clean_text(user['phone']),
            "email": clean_text(user['email']),
            "dob": user['dob']
        })
    return jsonify(message="User not found"), 404

@app.route('/profile', methods=['POST'])
def update_profile():
    data = request.get_json()
    
    conn = get_db()
    try:
        conn.execute('''
            UPDATE patients 
            SET name = ?, address = ?, phone = ?
            WHERE email = ?
        ''', (data['name'], data['address'], data['phone'], "john@example.com"))
        conn.commit()
        return jsonify(success=True, message="Profile updated successfully!")
    except Exception as e:
        app.logger.error(f"DB Error: {e}")
        return jsonify(success=False, message="Error saving profile"), 500
    finally:
        conn.close()

@app.route('/patients', methods=['GET'])
def get_patients():
    conn = get_db()
    users = conn.execute('SELECT * FROM patients').fetchall()
    conn.close()
    
    patient_list = []
    for user in users:
        patient_list.append({
            "name": clean_text(user['name']),
            "dob": user['dob'],
            "mrn": f"MRN-{user['ssn'][-4:]}",
            "status": "Stable"
        })
    return jsonify(patient_list)

@app.route('/forgot-password', methods=['POST'])
def forgot_password():
    data = request.get_json()
    email = data.get('email')
    
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (email,)).fetchone()
    conn.close()

    if user:
        try:
            pdf_filename = "reset_instructions.pdf"
            create_reset_pdf(pdf_filename, email)
            return jsonify(success=True, message="Reset generated!")
        except Exception as e:
            return jsonify(success=False, message="Server error"), 500

    return jsonify(success=False, message="Email not found"), 404

@app.route('/download-instructions', methods=['GET'])
def download_instructions():
    try:
        pdf_filename = "reset_instructions.pdf"
        if not os.path.exists(pdf_filename):
            create_reset_pdf(pdf_filename, "demo@example.com")
        return send_file(pdf_filename, as_attachment=True)
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route('/appointments', methods=['GET'])
def get_appointments():
    conn = get_db()
    records = conn.execute('SELECT * FROM medical_records WHERE patient_email = ?', ("john@example.com",)).fetchall()
    conn.close()

    formatted_events = {}
    for record in records:
        date_key = f"{record['date']}T00:00:00Z" 
        if date_key not in formatted_events: formatted_events[date_key] = []
        formatted_events[date_key].append({
            'title': f"{clean_text(record['provider'])} – {clean_text(record['specialty'])}",
            'time': "10:00 AM",
            'type': 'appointment'
        })
    return jsonify(formatted_events)

@app.route('/reset-password', methods=['POST'])
def reset_password():
    data = request.get_json()
    email = data.get('email')
    new_password = data.get('new_password')
    
    # SECURITY: Hash the new password before updating DB
    hashed_pw = generate_password_hash(new_password)

    conn = get_db()
    try:
        conn.execute('''
            UPDATE patients 
            SET password = ?
            WHERE email = ?
        ''', (hashed_pw, email))
        conn.commit()
        return jsonify(success=True, message="Password updated successfully. Please login.")
    except Exception as e:
        app.logger.error(f"Reset Error: {e}")
        return jsonify(success=False, message="Failed to update password"), 500
    finally:
        conn.close()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))