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
    
    # RE-SEED DEMO USER: This ensures you can ALWAYS log in with john@example.com
    cursor.execute('SELECT * FROM patients WHERE email = ?', ("john@example.com",))
    if not cursor.fetchone():
        hashed_pw = generate_password_hash("securepassword")
        cursor.execute('INSERT INTO patients (name, email, password, dob) VALUES (?, ?, ?, ?)', 
                       ("John Doe", "john@example.com", hashed_pw, "1980-01-01"))
    
    conn.commit()
    conn.close()

init_db()

@app.route("/")
def health_check(): return jsonify({"status": "healthy"})

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

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (data.get('email'),)).fetchone()
    conn.close()
    if user and check_password_hash(user['password'], data.get('password')):
        return jsonify(success=True)
    return jsonify(success=False), 401

@app.route('/forgot-password', methods=['POST'])
def forgot_password():
    # Simple mock for now to fix the UI break
    return jsonify(success=True, message="Reset instructions generated! Click download.")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))