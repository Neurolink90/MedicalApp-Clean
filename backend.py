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

def get_db():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cursor = conn.cursor()
    # Create all necessary tables
    cursor.execute('CREATE TABLE IF NOT EXISTS patients (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, dob TEXT, ssn TEXT, address TEXT, email TEXT UNIQUE NOT NULL, phone TEXT, password TEXT NOT NULL)')
    cursor.execute('CREATE TABLE IF NOT EXISTS medications (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, name TEXT, dosage TEXT, frequency TEXT, reminder_time TEXT)')
    cursor.execute('CREATE TABLE IF NOT EXISTS vitals (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, type TEXT, value TEXT, unit TEXT, timestamp TEXT)')
    cursor.execute('CREATE TABLE IF NOT EXISTS documents (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, filename TEXT, file_type TEXT, upload_date TEXT, file_data BLOB)')
    cursor.execute('CREATE TABLE IF NOT EXISTS medical_records (id INTEGER PRIMARY KEY AUTOINCREMENT, patient_email TEXT, date TEXT, provider TEXT, specialty TEXT, content TEXT)')
    
    # PERMANENT SEED: Recreates Zach's account automatically on restart
    cursor.execute('SELECT * FROM patients WHERE email = ?', ("zach@example.com",))
    if not cursor.fetchone():
        hashed_pw = generate_password_hash("helloandgoodbye0")
        cursor.execute('''
            INSERT INTO patients (name, email, password, dob, address, phone) 
            VALUES (?, ?, ?, ?, ?, ?)
        ''', ("Zach SQLite", "zach@example.com", hashed_pw, "1990-01-01", "123 Main St", "555-1234"))
    
    conn.commit()
    conn.close()

init_db()

# --- AUTH & REGISTRATION ---

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    conn = get_db()
    user = conn.execute('SELECT * FROM patients WHERE email = ?', (data.get('email'),)).fetchone()
    conn.close()
    if user and check_password_hash(user['password'], data.get('password')):
        return jsonify(success=True, email=user['email'])
    return jsonify(success=False), 401

@app.route('/patients', methods=['GET'])
def get_patients():
    conn = get_db()
    users = conn.execute('SELECT name, dob, ssn, email FROM patients').fetchall()
    conn.close()
    return jsonify([dict(u) for u in users])

# --- TRACKERS & DOCUMENTS ---

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

@app.route('/share/<int:doc_id>', methods=['GET'])
def share_document(doc_id):
    conn = get_db()
    doc = conn.execute('SELECT filename, file_data, file_type FROM documents WHERE id = ?', (doc_id,)).fetchone()
    conn.close()
    if doc:
        return send_file(io.BytesIO(doc['file_data']), mimetype=doc['file_type'], as_attachment=False, download_name=doc['filename'])
    return "<h1>Document Not Found</h1>", 404

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))