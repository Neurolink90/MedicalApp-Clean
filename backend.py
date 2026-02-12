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

def get_db():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute('CREATE TABLE IF NOT EXISTS patients (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, dob TEXT, ssn TEXT, address TEXT, email TEXT UNIQUE NOT NULL, phone TEXT, password TEXT NOT NULL)')
    cursor.execute('CREATE TABLE IF NOT EXISTS medical_records (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, date TEXT, provider TEXT, specialty TEXT, content TEXT)')
    cursor.execute('CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, filename TEXT, file_type TEXT, upload_date TEXT, file_data BLOB)')
    
    # Ensure Zach exists with the correct password
    cursor.execute('SELECT * FROM patients WHERE email = ?', ("zach@example.com",))
    if not cursor.fetchone():
        hashed_pw = generate_password_hash("hellloandgoodbye0")
        cursor.execute('INSERT INTO patients (name, email, password, dob, address, phone) VALUES (?, ?, ?, ?, ?, ?)', 
                       ("Zach SQLite", "zach@example.com", hashed_pw, "1980-01-01", "123 Main St", "555-1234"))
        # Add test appointment for Zach
        cursor.execute('INSERT INTO medical_records (patient_email, date, provider, specialty) VALUES (?, ?, ?, ?)',
                       ("zach@example.com", "2026-02-15", "Dr. Smith", "Cardiology"))
    conn.commit()
    conn.close()

init_db()

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (data.get('email'),)).fetchone()
    conn.close()
    if user and check_password_hash(user['password'], data.get('password')):
        return jsonify(success=True, email=user['email'])
    return jsonify(success=False, message="Invalid Credentials"), 401

@app.route('/profile', methods=['GET', 'POST'])
def handle_profile():
    # Fix: Get email from URL parameters
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

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    hashed_pw = generate_password_hash(data.get('password'))
    conn = get_db()
    try:
        conn.execute('INSERT INTO patients (name, email, password) VALUES (?, ?, ?)', (data.get('name'), data.get('email'), hashed_pw))
        conn.commit()
        return jsonify(success=True)
    except: return jsonify(success=False, message="User already exists"), 400
    finally: conn.close()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))